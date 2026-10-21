"""Lumear buyer development API. Python 3.11+, standard library only.

Run: python backend/server.py. Database is created beside this file.
All writes run in a SQLite transaction; money is stored as integer centavos.
This is a local development server, not a production payment/auth deployment.
"""
import argparse
import base64
import hashlib
import hmac
import json
import math
import re
import secrets
import sqlite3
import time
import sys
from datetime import date
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse


class Problem(Exception):
    def __init__(self, message, status=422):
        self.message, self.status = message, status


def require(condition, message, status=422):
    if not condition:
        raise Problem(message, status)


def text(value, label, minimum=1, maximum=500):
    require(isinstance(value, str), f'{label} is required.')
    value = value.strip()
    require(minimum <= len(value) <= maximum,
            f'{label} must contain {minimum} to {maximum} characters.')
    return value


def integer(value, label, minimum=1, maximum=99999):
    require(type(value) is int and minimum <= value <= maximum,
            f'{label} must be a whole number from {minimum} to {maximum}.')
    return value


def password_hash(password, salt):
    return hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 210000).hex()


def photo_files(files, minimum=0):
    require(isinstance(files, list) and minimum <= len(files) <= 5,
            f'Attach {minimum} to 5 JPG or PNG photos.')
    result = []
    for f in files:
        require(isinstance(f, dict), 'Invalid photo.')
        try:
            raw = base64.b64decode(f.get('data', ''), validate=True)
        except (ValueError, TypeError):
            raise Problem('Invalid photo data.')
        require(0 < len(raw) <= 5 * 1024 * 1024, 'Photos must be at most 5 MB each.')
        # Check signatures as well as image structure, rather than trusting filenames.
        png = (raw.startswith(b'\x89PNG\r\n\x1a\n') and b'IHDR' in raw[:20]
               and raw.endswith(b'IEND\xaeB`\x82'))
        jpg = raw.startswith(b'\xff\xd8\xff') and raw.endswith(b'\xff\xd9')
        require(png or jpg, 'Only JPG or PNG image content is accepted.')
        result.append({'name': text(f.get('name'), 'Photo name', 1, 120),
                       'data': f['data'], 'type': 'image/png' if png else 'image/jpeg'})
    return result


class Store:
    def __init__(self, path):
        self.path = str(path)
        with self.transaction() as db:
            db.executescript('''
              CREATE TABLE IF NOT EXISTS records (
                kind TEXT, id TEXT, owner TEXT, data TEXT NOT NULL,
                PRIMARY KEY(kind,id,owner));
              CREATE INDEX IF NOT EXISTS record_owner ON records(kind,owner);
              CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY, email TEXT UNIQUE COLLATE NOCASE,
                salt TEXT, hash TEXT, name TEXT, phone TEXT, role TEXT);
              CREATE TABLE IF NOT EXISTS sessions (
                token TEXT PRIMARY KEY, owner TEXT, touched REAL);
              CREATE TABLE IF NOT EXISTS submissions (
                owner TEXT, key TEXT, fingerprint TEXT, response TEXT,
                PRIMARY KEY(owner,key));
            ''')
            # Upgrade development databases created before owner-scoped keys.
            columns = db.execute('PRAGMA table_info(records)').fetchall()
            if not next(c['pk'] for c in columns if c['name'] == 'owner'):
                db.execute('ALTER TABLE records RENAME TO records_legacy')
                db.execute('CREATE TABLE records(kind TEXT,id TEXT,owner TEXT,data TEXT NOT NULL,PRIMARY KEY(kind,id,owner))')
                db.execute('INSERT INTO records SELECT * FROM records_legacy')
                db.execute('DROP TABLE records_legacy')
                db.execute('CREATE INDEX IF NOT EXISTS record_owner ON records(kind,owner)')
            if not self.list(db, 'product'):
                self.seed(db)

    @contextmanager
    def transaction(self):
        db = sqlite3.connect(self.path, timeout=15)
        db.row_factory = sqlite3.Row
        try:
            db.execute('BEGIN IMMEDIATE')
            yield db
            db.commit()
        except Exception:
            db.rollback()
            raise
        finally:
            db.close()

    def put(self, db, kind, obj, owner=''):
        db.execute('INSERT OR REPLACE INTO records VALUES(?,?,?,?)',
                   (kind, obj['id'], owner, json.dumps(obj)))
        return obj

    def list(self, db, kind, owner=None):
        query, args = 'SELECT data FROM records WHERE kind=?', [kind]
        if owner is not None:
            query += ' AND owner=?'
            args.append(owner)
        return [json.loads(r[0]) for r in db.execute(query, args)]

    def get(self, db, kind, id, owner=None):
        query, args = 'SELECT data FROM records WHERE kind=? AND id=?', [kind, id]
        if owner is not None:
            query += ' AND owner=?'
            args.append(owner)
        row = db.execute(query, args).fetchone()
        require(row is not None, 'Record not found.', 404)
        return json.loads(row[0])

    def remove(self, db, kind, id, owner):
        self.get(db, kind, id, owner)
        db.execute('DELETE FROM records WHERE kind=? AND id=? AND owner=?', (kind, id, owner))

    def seed(self, db):
        for id, email, password, name, phone in [
            ('demo', 'lumear@gmail.com', 'Lumear123', 'Lumear Buyer', '09170000000'),
            ('buyer1', 'juanmiguel.delacruz@example.com', 'Mamimili@2026', 'Juan Miguel Dela Cruz', '09171234567'),
            ('buyer2', 'anamarie.reyes@example.com', 'Suki#2026Ana', 'Ana Marie Reyes', '09173456789'),
        ]:
            salt = secrets.token_hex(16)
            db.execute('INSERT OR IGNORE INTO users VALUES(?,?,?,?,?,?,?)',
                       (id, email, salt, password_hash(password, salt), name, phone, 'buyer'))
        for id, owner, label, city, province, zone, street in [
            ('ADDR-DEMO', 'demo', 'Home', 'Quezon City', 'Metro Manila', 'NCR', '45 Kalayaan Ave., Brgy. Central'),
            ('ADDR-1', 'buyer1', 'Home', 'Quezon City', 'Metro Manila', 'NCR', '45 Kalayaan Ave., Brgy. Central'),
            ('ADDR-2', 'buyer1', 'Office', 'Makati City', 'Metro Manila', 'NCR', '12F Pacific Tower, 6750 Ayala Ave., Brgy. San Lorenzo'),
            ('ADDR-3', 'buyer2', 'Home', 'Cebu City', 'Cebu', 'Visayas', '78 Osmeña Blvd., Brgy. Capitol Site'),
            ('ADDR-4', 'buyer1', 'Province', 'Itbayat', 'Batanes', 'Unserviceable', 'Purok 2, Brgy. Raele'),
        ]:
            user = db.execute('SELECT * FROM users WHERE id=?', (owner,)).fetchone()
            self.put(db, 'address', dict(id=id, label=label, name=user['name'], phone=user['phone'],
                street=street, city=city, province=province, zone=zone,
                default=id in ('ADDR-1', 'ADDR-3', 'ADDR-DEMO')), owner)
        products = [
            ('P-01', 'Abaca Woven Tote Bag', 19900, 36, 400, 's1', 'Bags'),
            ('P-02', 'Rattan Fruit Basket', 45000, 20, 800, 's1', 'Home & Living'),
            ('P-03', 'Capiz Shell Lamp', 125000, 1, 1500, 's1', 'Home & Living'),
            ('P-04', 'Banig Placemat Set of 4', 35000, 0, 500, 's1', 'Home & Living'),
            ('P-05', 'USB-C Fast Charger 20W', 39900, 50, 200, 's2', 'Electronics'),
            ('P-06', 'Wireless Earbuds X2', 149900, 20, 300, 's2', 'Electronics'),
            ('P-07', 'Power Bank 10000mAh', 89900, 5, 400, 's2', 'Electronics'),
        ]
        for id, name, price, stock, grams, seller, category in products:
            variants = [{'id': '', 'label': 'Standard', 'price': price, 'stock': stock}]
            if id == 'P-01':
                variants = [dict(id=f'{color}-{size}', label=f'{color} / {size}', price=p, stock=s)
                    for color, counts in [('Natural', [10, 8, 5]), ('Black', [10, 0, 3])]
                    for size, p, s in zip(['S', 'M', 'L'], [19900, 24900, 29900], counts)]
            if id == 'P-06':
                variants = [dict(id=c, label=c, price=price, stock=10) for c in ['Black', 'White']]
            self.put(db, 'product', dict(id=id, name=name, price=price, stock=stock,
                grams=grams, seller=seller, category=category, variants=variants,
                store='Maria Clara Handicrafts' if seller == 's1' else 'RV Gadget Hub',
                origin='NCR' if seller == 's1' else 'Visayas', vacation=False,
                approved=True, active=True, limit=2 if id == 'P-07' else 99999,
                description=f'{name}. Check the available variants and stock before ordering.'))
        now = time.time()
        for code, kind, amount, minimum, cap, seller in [
            ('MCH50', 'store', 5000, 30000, 5000, 's1'),
            ('MCH10', 'store', 10, 50000, 10000, 's1'),
            ('RV10', 'store', 10, 50000, 15000, 's2'),
            ('PLAT100', 'platform', 10000, 100000, 10000, ''),
            ('FREESHIP', 'shipping', 5000, 30000, 5000, ''),
            ('MCHOLD', 'store', 5000, 30000, 5000, 's1'),
            ('MCHSOON', 'store', 5000, 30000, 5000, 's1'),
            ('MCHMAX', 'store', 5000, 30000, 5000, 's1'),
        ]:
            self.put(db, 'voucher', dict(id=code, kind=kind, amount=amount,
                percent=code in ('MCH10', 'RV10'), minimum=minimum, cap=cap, seller=seller,
                start=now + 86400 if code == 'MCHSOON' else now - 86400,
                end=now - 1 if code == 'MCHOLD' else now + 30 * 86400,
                limit=0 if code == 'MCHMAX' else 1000, used=0))

    def notify(self, db, owner, title, order_id=''):
        self.put(db, 'notification', dict(id=secrets.token_hex(12), title=title,
                 order_id=order_id, read=False, date=time.time()), owner)

    def authenticate(self, db, token):
        row = db.execute('SELECT * FROM sessions WHERE token=?', (token,)).fetchone()
        require(row is not None and time.time() - row['touched'] < 1800,
                'Your session expired. Please sign in again.', 401)
        db.execute('UPDATE sessions SET touched=? WHERE token=?', (time.time(), token))
        user = dict(db.execute('SELECT id,email,name,phone,role FROM users WHERE id=?',
                               (row['owner'],)).fetchone())
        require(user['role'] == 'buyer', 'Buyer access required.', 403)
        return user

    def voucher(self, db, code, owner, amount):
        code = text(code, 'Voucher code', 4, 12).upper()
        require(re.fullmatch('[A-Z0-9]{4,12}', code), 'Use 4 to 12 letters and digits for voucher codes.')
        rows = [v for v in self.list(db, 'voucher') if v['id'] == code]
        require(rows, 'Voucher code not found.')
        v = rows[0]
        require(time.time() >= v['start'], f'{code} has not started yet.')
        require(time.time() < v['end'], f'{code} has expired.')
        require(v['used'] < v['limit'], f'{code} has reached its usage limit.')
        wallet = self.list(db, 'wallet', owner)
        require(any(w['code'] == code and not w['used'] for w in wallet), f'Claim {code} first, or it has already been used.')
        require(amount >= v['minimum'], f"Spend ₱{(v['minimum'] - amount) / 100:.2f} more to use {code}.")
        return v

    def quote(self, db, owner, body):
        address = self.get(db, 'address', body.get('address_id', ''), owner)
        require(address['zone'] != 'Unserviceable', 'This address is not serviceable. Choose another delivery address.')
        cart = self.list(db, 'cart', owner)
        require(cart, 'Your cart is empty.')
        groups = {}
        for item in cart:
            p = self.get(db, 'product', item['product_id'])
            require(p['active'] and p['approved'], f"{p['name']} is no longer available.")
            require(not p['vacation'], f"{p['store']} is on vacation.")
            v = next((v for v in p['variants'] if v['id'] == item['variant_id']), None)
            require(v and item['quantity'] <= v['stock'], f"Not enough stock for {p['name']}.")
            purchased = sum(i['quantity'] for o in self.list(db, 'order', owner)
                            if o['status'] != 'Cancelled' for i in o['items'] if i['product_id'] == p['id'])
            require(item['quantity'] + purchased <= p['limit'], f"Purchase limit reached for {p['name']}.")
            g = groups.setdefault(p['seller'], dict(seller=p['seller'], store=p['store'],
                origin=p['origin'], grams=0, subtotal=0, shipping=0, discount=0, items=[], codes=[]))
            g['grams'] += p['grams'] * item['quantity']
            g['subtotal'] += v['price'] * item['quantity']
            g['items'].append(dict(item, name=p['name'], variant=v['label'], price=v['price']))
        for g in groups.values():
            same = g['origin'] == address['zone']
            base, extra = (5000, 1500) if same and address['zone'] == 'NCR' else (6000, 2000) if same else (12000, 2500)
            g['shipping'] = base + max(0, math.ceil(g['grams'] / 1000) - 1) * extra
        subtotal = sum(g['subtotal'] for g in groups.values())
        shipping = sum(g['shipping'] for g in groups.values())
        codes, occupied, discounts = body.get('vouchers', []), set(), []
        require(isinstance(codes, list) and len(codes) <= len(groups) + 2, 'Select one voucher of each type per store.')
        for code in codes:
            candidates = [v for v in self.list(db, 'voucher') if v['id'] == str(code).upper()]
            require(candidates, 'Voucher code not found.')
            candidate = candidates[0]
            base = groups.get(candidate['seller'], {}).get('subtotal', 0) if candidate['kind'] == 'store' else subtotal
            v = self.voucher(db, code, owner, base)
            key = v['kind'] + v['seller']
            require(key not in occupied, 'Only one voucher of each type is allowed per store.')
            occupied.add(key)
            discount = min(v['cap'], (base * v['amount'] + 50) // 100 if v['percent'] else v['amount'],
                           shipping if v['kind'] == 'shipping' else base)
            discounts.append(dict(code=v['id'], amount=discount, kind=v['kind']))
            targets = [groups[v['seller']]] if v['kind'] == 'store' else list(groups.values())
            remaining = discount
            targets.sort(key=lambda g: g['subtotal'], reverse=True)
            # Allocate the rounding remainder to the largest store.
            for g in targets[1:]:
                share = (discount * g['subtotal'] + subtotal // 2) // subtotal
                g['discount'] += share
                g['codes'].append(v['id'])
                remaining -= share
            targets[0]['discount'] += remaining
            targets[0]['codes'].append(v['id'])
        for g in groups.values():
            g['total'] = max(0, g['subtotal'] + g['shipping'] - g['discount'])
        return dict(address=address, stores=list(groups.values()), subtotal=subtotal, shipping=shipping,
                    discounts=discounts, total=sum(g['total'] for g in groups.values()))

    def cancel(self, db, owner, order, reason):
        if order['status'] == 'Cancelled':
            return order
        require(order['status'] in ('To Pay', 'To Ship') and not order.get('ready_for_pickup'),
                'Cancellation is no longer available after Ready for Pickup.')
        for item in order['items']:
            p = self.get(db, 'product', item['product_id'])
            for v in p['variants']:
                if v['id'] == item['variant_id']:
                    v['stock'] += item['quantity']
            p['stock'] = sum(v['stock'] for v in p['variants'])
            self.put(db, 'product', p)
        for code in order['codes']:
            # A platform voucher shared by split orders is released only after all are cancelled.
            others = [o for o in self.list(db, 'order', owner) if o['id'] != order['id']
                      and o.get('checkout_id') == order['checkout_id'] and code in o['codes'] and o['status'] != 'Cancelled']
            if not others:
                v = self.get(db, 'voucher', code)
                v['used'] = max(0, v['used'] - 1)
                self.put(db, 'voucher', v)
                for w in self.list(db, 'wallet', owner):
                    if w['code'] == code:
                        w['used'] = False
                        self.put(db, 'wallet', w, owner)
        order.update(status='Cancelled', cancellation_reason=reason,
                     refund_status='Pending provider refund' if order.get('paid') else 'Not charged')
        order['timeline'].append(dict(title='Cancelled', date=time.time()))
        self.put(db, 'order', order, owner)
        self.notify(db, owner, f"{order['id']}: Cancelled", order['id'])
        self.notify(db, order['seller'], f"{order['id']}: Cancelled — {reason}", order['id'])
        return order

    def maintenance(self, db, owner):
        for o in self.list(db, 'order', owner):
            if o['status'] == 'To Pay' and time.time() - o['date'] >= 3600:
                self.cancel(db, owner, o, 'Payment not received within 1 hour')
            elif o['status'] == 'To Receive' and o.get('delivered_at') and time.time() - o['delivered_at'] > 604800:
                o.update(status='Completed', completed_at=time.time())
                o['timeline'].append(dict(title='Completed', date=time.time()))
                self.put(db, 'order', o, owner)
                self.notify(db, owner, f"{o['id']}: Completed", o['id'])

    def dispatch(self, method, url, body=None, token=''):
        body = body or {}
        require(isinstance(body, dict), 'Send a JSON object.')
        parsed = urlparse(url)
        path, query = parsed.path.removeprefix('/api').rstrip('/'), parse_qs(parsed.query)
        with self.transaction() as db:
            if path == '/health' and method == 'GET':
                return {'status': 'ok'}
            if path == '/auth/login' and method == 'POST':
                email = text(body.get('email'), 'Email', 3, 254).lower()
                password = body.get('password')
                require(isinstance(password, str) and 1 <= len(password) <= 128, 'Enter your password.')
                user = db.execute('SELECT * FROM users WHERE email=?', (email,)).fetchone()
                require(user and hmac.compare_digest(user['hash'], password_hash(password, user['salt'])),
                        'Invalid email or password.', 401)
                token = secrets.token_urlsafe(32)
                db.execute('INSERT INTO sessions VALUES(?,?,?)', (token, user['id'], time.time()))
                return {'token': token, 'name': user['name']}
            if path == '/auth/register' and method == 'POST':
                email = text(body.get('email'), 'Email', 3, 254).lower()
                require(re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', email), 'Enter a valid email address.')
                password = text(body.get('password'), 'Password', 8, 128)
                require(re.search('[A-Z]', password) and re.search('[a-z]', password) and re.search('[0-9]', password),
                        'Use uppercase, lowercase and a number in your password.')
                name = text(body.get('name'), 'Name', 2, 100)
                require(all(c.isalpha() or c in " .'-" for c in name), 'Name must contain letters and valid name punctuation.')
                phone = text(body.get('phone'), 'Phone', 11, 13)
                if phone.startswith('+63'):
                    phone = '0' + phone[3:]
                require(re.fullmatch('09[0-9]{9}', phone), 'Enter an 11-digit Philippine mobile number starting with 09.')
                try:
                    born = date.fromisoformat(body.get('date_of_birth', ''))
                except (ValueError, TypeError):
                    raise Problem('Enter a valid date of birth.')
                today = date.today()
                age = today.year - born.year - ((today.month, today.day) < (born.month, born.day))
                require(18 <= age <= 120, 'You must be at least 18 years old to create an account.')
                require(not db.execute('SELECT 1 FROM users WHERE email=?', (email,)).fetchone(), 'Email already registered.')
                salt, id = secrets.token_hex(16), secrets.token_hex(12)
                db.execute('INSERT INTO users VALUES(?,?,?,?,?,?,?)',
                           (id, email, salt, password_hash(password, salt), name, phone, 'buyer'))
                return {'message': 'Account created. You can now sign in.'}
            if path == '/auth/google':
                raise Problem('Google sign-in needs a configured OAuth client and verified ID-token exchange. Use email sign-in for this local server.', 503)
            user = self.authenticate(db, token)
            owner = user['id']
            self.maintenance(db, owner)
            if path == '/auth/logout' and method == 'POST':
                db.execute('DELETE FROM sessions WHERE token=?', (token,))
                return {'message': 'Signed out.'}
            if path == '/capabilities' and method == 'GET':
                return {'storage': 'sqlite', 'checkout': True}
            if path == '/auth/password' and method == 'POST':
                current = body.get('current_password', '')
                require(isinstance(current, str), 'Enter your current password.')
                row = db.execute('SELECT * FROM users WHERE id=?', (owner,)).fetchone()
                require(hmac.compare_digest(row['hash'], password_hash(current, row['salt'])), 'Current password is incorrect.')
                new = body.get('new_password', '')
                require(isinstance(new, str) and 8 <= len(new) <= 128, 'New password must contain 8 to 128 characters.')
                for pattern, message in [('[A-Z]', 'an uppercase letter'), ('[a-z]', 'a lowercase letter'),
                                         ('[0-9]', 'a number'), ('[^A-Za-z0-9\\s]', 'a special character')]:
                    require(re.search(pattern, new), f'New password must contain {message}.')
                require(new == body.get('confirm_password'), 'Password confirmation does not match.')
                require(new != current, 'New password must differ from your current password.')
                salt = secrets.token_hex(16)
                db.execute('UPDATE users SET salt=?,hash=? WHERE id=?', (salt, password_hash(new, salt), owner))
                db.execute('DELETE FROM sessions WHERE owner=? AND token<>?', (owner, token))
                return {'message': 'Password changed. Other sessions have been signed out.'}
            if path == '/me':
                require(method in ('GET', 'PATCH'), 'Method not allowed.', 405)
                saved = self.list(db, 'profile', owner)
                if method == 'PATCH':
                    name = text(body.get('name'), 'Name', 2, 100)
                    require(all(c.isalpha() or c in " .'-" for c in name), 'Name must contain letters, spaces, apostrophes, hyphens or periods.')
                    require(body.get('phone', user['phone']) == user['phone'], 'Phone changes require OTP verification, which is not configured.')
                    db.execute('UPDATE users SET name=? WHERE id=?', (name, owner))
                    user.update(name=name)
                    if 'photos' in body and body['photos']:
                        photos = photo_files(body['photos'], 1)
                        require(len(photos) == 1, 'Choose one profile photo.')
                        saved = [self.put(db, 'profile', dict(id=owner, photo=photos[0]), owner)]
                if saved:
                    user['photo'] = saved[0]['photo']
                return user
            if path == '/products' and method == 'GET':
                products = [p for p in self.list(db, 'product') if p['active'] and p['approved']]
                search = query.get('q', [''])[0].strip().lower()
                products = [p for p in products if search in p['name'].lower() or search in p['description'].lower()]
                category = query.get('category', [''])[0]
                if category:
                    products = [p for p in products if p['category'] == category]
                for p in products:
                    reviews = [r for r in self.list(db, 'review') if r['product_id'] == p['id']]
                    p['review_count'] = len(reviews)
                    p['rating'] = sum(r['stars'] for r in reviews) / len(reviews) if reviews else 0
                sort = query.get('sort', ['name'])[0]
                products.sort(key=lambda p: p['price'] if sort.startswith('price') else p['rating'] if sort == 'rating' else p['name'],
                              reverse=sort in ('price_desc', 'rating'))
                return products
            if path.startswith('/products/') and method == 'GET':
                p = self.get(db, 'product', path.split('/')[2])
                require(p['active'] and p['approved'], 'Product no longer available.', 404)
                p['reviews'] = [r for r in self.list(db, 'review') if r['product_id'] == p['id']]
                return p
            if path == '/addresses':
                if method == 'GET':
                    return self.list(db, 'address', owner)
                require(method == 'POST', 'Method not allowed.', 405)
                require(len(self.list(db, 'address', owner)) < 10, 'You can save up to 10 addresses.')
                return self.save_address(db, owner, body)
            if path.startswith('/addresses/'):
                id = path.split('/')[2]
                a = self.get(db, 'address', id, owner)
                if method == 'GET':
                    return a
                if method == 'DELETE':
                    require(not a['default'], 'Choose another default address before deleting this address.')
                    self.remove(db, 'address', id, owner)
                    return {'message': 'Address deleted.'}
                require(method == 'PATCH', 'Method not allowed.', 405)
                return self.save_address(db, owner, dict(a, **body), id)
            if path in ('/wishlist', '/follows') or path.startswith(('/wishlist/', '/follows/')):
                kind = 'wishlist' if path.startswith('/wishlist') else 'follow'
                if method == 'GET':
                    return self.list(db, kind, owner)
                id = path.split('/')[-1]
                if method == 'DELETE':
                    self.remove(db, kind, id, owner)
                    return {'message': 'Removed.'}
                require(method == 'POST', 'Method not allowed.', 405)
                if kind == 'wishlist':
                    self.get(db, 'product', id)
                else:
                    require(id in ('s1', 's2'), 'Store not found.', 404)
                return self.put(db, kind, {'id': id}, owner)
            if path == '/cart':
                if method == 'GET':
                    return self.list(db, 'cart', owner)
                require(method == 'POST', 'Method not allowed.', 405)
                p = self.get(db, 'product', body.get('product_id', ''))
                require(p['active'] and p['approved'] and not p['vacation'], 'Product is unavailable or store is on vacation.')
                variant = body.get('variant_id', '')
                v = next((v for v in p['variants'] if v['id'] == variant), None)
                require(v, 'Please select a valid product variant.')
                qty = integer(body.get('quantity'), 'Quantity')
                id = f"{p['id']}:{variant}"
                old = next((i for i in self.list(db, 'cart', owner) if i['id'] == id), None)
                qty += old['quantity'] if old else 0
                require(qty <= v['stock'] and qty <= p['limit'], 'Quantity exceeds available stock or purchase limit.')
                return self.put(db, 'cart', dict(id=id, product_id=p['id'], variant_id=variant,
                    quantity=qty, name=p['name'], variant=v['label'], price=v['price'], store=p['store']), owner)
            if path.startswith('/cart/'):
                id = path.split('/')[2]
                item = self.get(db, 'cart', id, owner)
                if method == 'DELETE':
                    self.remove(db, 'cart', id, owner)
                    return {'message': 'Item removed.'}
                require(method == 'PATCH', 'Method not allowed.', 405)
                qty = integer(body.get('quantity'), 'Quantity')
                p = self.get(db, 'product', item['product_id'])
                v = next(v for v in p['variants'] if v['id'] == item['variant_id'])
                require(qty <= v['stock'] and qty <= p['limit'], 'Quantity exceeds available stock or purchase limit.')
                item['quantity'] = qty
                return self.put(db, 'cart', item, owner)
            if path == '/vouchers' and method == 'GET':
                wallet = self.list(db, 'wallet', owner)
                return [dict(v, claimed=any(w['code'] == v['id'] for w in wallet),
                             redeemed=any(w['code'] == v['id'] and w['used'] for w in wallet))
                        for v in self.list(db, 'voucher')]
            if path.startswith('/vouchers/') and method == 'POST':
                code = path.split('/')[2].upper()
                v = self.get(db, 'voucher', code)
                require(v['start'] <= time.time() < v['end'], 'Voucher is expired or has not started.')
                require(v['used'] < v['limit'], 'Voucher usage limit reached.')
                return self.put(db, 'wallet', dict(id=code, code=code, used=any(
                    w['code'] == code and w['used'] for w in self.list(db, 'wallet', owner))), owner)
            if path == '/checkout/quote' and method == 'POST':
                return self.quote(db, owner, body)
            if path == '/checkout' and method == 'POST':
                key = text(body.get('idempotency_key'), 'Checkout request key', 8, 128)
                fingerprint = hashlib.sha256(json.dumps(body, sort_keys=True).encode()).hexdigest()
                previous = db.execute('SELECT * FROM submissions WHERE owner=? AND key=?', (owner, key)).fetchone()
                if previous:
                    require(previous['fingerprint'] == fingerprint, 'This checkout key has already been used for another request.', 409)
                    return json.loads(previous['response'])
                quote = self.quote(db, owner, body)
                require(body.get('expected_quote') == quote, 'Prices, stock or shipping changed. Review the refreshed total before placing your order.', 409)
                note = text(body.get('note', ' '), 'Note', 0, 200)
                require(body.get('payment_method') == 'COD', 'Only COD is enabled until a payment provider is configured.')
                orders = []
                checkout_id = secrets.token_hex(12)
                for g in quote['stores']:
                    for item in g['items']:
                        p = self.get(db, 'product', item['product_id'])
                        for v in p['variants']:
                            if v['id'] == item['variant_id']:
                                v['stock'] -= item['quantity']
                        p['stock'] = sum(v['stock'] for v in p['variants'])
                        self.put(db, 'product', p)
                        self.remove(db, 'cart', item['id'], owner)
                    o = dict(g, id='LM' + secrets.token_hex(6).upper(), checkout_id=checkout_id,
                        address=quote['address'].copy(), note=note, payment_method='COD', paid=False,
                        date=time.time(), status='To Ship', timeline=[dict(title='Order placed', date=time.time())])
                    self.put(db, 'order', o, owner)
                    self.notify(db, owner, f"{o['id']}: Order placed", o['id'])
                    self.notify(db, o['seller'], f"{o['id']}: New order", o['id'])
                    orders.append(o)
                for d in quote['discounts']:
                    v = self.get(db, 'voucher', d['code'])
                    v['used'] += 1
                    self.put(db, 'voucher', v)
                    self.put(db, 'wallet', dict(id=v['id'], code=v['id'], used=True), owner)
                result = {'orders': orders, 'total': quote['total']}
                db.execute('INSERT INTO submissions VALUES(?,?,?,?)', (owner, key, fingerprint, json.dumps(result)))
                return result
            if path == '/orders' and method == 'GET':
                return sorted(self.list(db, 'order', owner), key=lambda o: o['date'], reverse=True)
            if path.startswith('/orders/'):
                parts = path.split('/')
                o = self.get(db, 'order', parts[2], owner)
                if method == 'GET':
                    return o
                require(method == 'POST' and len(parts) == 4, 'Method not allowed.', 405)
                action = parts[3]
                if action == 'cancel':
                    return self.cancel(db, owner, o, text(body.get('reason'), 'Cancellation reason', 10, 300))
                if action == 'receive':
                    if o['status'] == 'Completed':
                        return o
                    require(o['status'] == 'To Receive' and o.get('delivered_at'), 'Order Received is only available after delivery.')
                    o.update(status='Completed', completed_at=time.time())
                    o['timeline'].append(dict(title='Completed', date=time.time()))
                    self.notify(db, owner, f"{o['id']}: Completed", o['id'])
                    return self.put(db, 'order', o, owner)
                if action == 'return':
                    existing = [r for r in self.list(db, 'return', owner) if r['order_id'] == o['id']]
                    if existing:
                        return existing[0]
                    require(o['status'] == 'To Receive' and o.get('delivered_at') and time.time() - o['delivered_at'] <= 604800,
                            'Returns are available within 7 days of delivery, before completion.')
                    reason = body.get('reason')
                    require(reason in ('Damaged item', 'Wrong item', 'Missing item', 'Not as described'), 'Select a return reason.')
                    description = text(body.get('description'), 'Return description', 10, 500)
                    photos = photo_files(body.get('photos', []), 1)
                    o['status'] = 'Return/Refund'
                    self.put(db, 'order', o, owner)
                    self.notify(db, o['seller'], f"{o['id']}: Return requested", o['id'])
                    return self.put(db, 'return', dict(id=secrets.token_hex(12), order_id=o['id'],
                        reason=reason, description=description, photos=photos, status='Pending', date=time.time()), owner)
                if action == 'review':
                    require(o['status'] == 'Completed' and time.time() - o['completed_at'] <= 30 * 86400,
                            'Review a completed order within 30 days.')
                    pid = body.get('product_id')
                    require(any(i['product_id'] == pid for i in o['items']), 'This item is not in your order.')
                    stars = integer(body.get('stars'), 'Stars', 1, 5)
                    comment = text(body.get('text', ''), 'Review', 0, 500)
                    photos = photo_files(body.get('photos', []))
                    id = o['id'] + ':' + pid
                    old = next((r for r in self.list(db, 'review', owner) if r['id'] == id), None)
                    if old and old['stars'] == stars and old['text'] == comment and old['photos'] == photos:
                        return old
                    require(not old or not old['edited'], 'A review can only be edited once.')
                    return self.put(db, 'review', dict(id=id, product_id=pid, order_id=o['id'], stars=stars,
                        text=comment, photos=photos, reviewer=user['name'][0] + '***', date=old['date'] if old else time.time(),
                        edited=old is not None), owner)
                raise Problem('Action not available.', 404)
            if path == '/returns' and method == 'GET':
                return self.list(db, 'return', owner)
            if path == '/notifications':
                if method == 'POST':
                    for n in self.list(db, 'notification', owner):
                        n['read'] = True
                        self.put(db, 'notification', n, owner)
                return sorted(self.list(db, 'notification', owner), key=lambda n: n['date'], reverse=True)
            if path.startswith('/notifications/') and method == 'POST':
                n = self.get(db, 'notification', path.split('/')[2], owner)
                n['read'] = True
                return self.put(db, 'notification', n, owner)
            if path.startswith('/chat/'):
                seller = path.split('/')[2]
                require(seller in ('s1', 's2'), 'Store not found.', 404)
                messages = [m for m in self.list(db, 'message', owner) if m['seller'] == seller]
                if method == 'GET':
                    return sorted(messages, key=lambda m: m['date'])
                require(method == 'POST', 'Method not allowed.', 405)
                key = text(body.get('idempotency_key'), 'Message key', 8, 128)
                if any(m['id'] == key for m in messages):
                    return next(m for m in messages if m['id'] == key)
                message = text(body.get('text', ''), 'Message', 0, 1000)
                photos = photo_files(body.get('photos', []))
                require(message or photos, 'Write a message or attach a photo.')
                self.notify(db, seller, 'New buyer message')
                return self.put(db, 'message', dict(id=key, seller=seller, text=message,
                    photos=photos, date=time.time(), sender=user['name']), owner)
            raise Problem('Endpoint not found.', 404)

    def save_address(self, db, owner, body, id=None):
        fields = {k: text(body.get(k), k.replace('_', ' ').title(), 1, 150)
                  for k in ('label', 'name', 'phone', 'street', 'city', 'province', 'zone')}
        require(re.fullmatch(r'(09[0-9]{9}|\+639[0-9]{9})', fields['phone']), 'Enter a Philippine mobile number starting with 09 or +639.')
        require(fields['zone'] in ('NCR', 'Visayas', 'CALABARZON', 'Mindanao', 'Unserviceable'), 'Choose a valid shipping zone.')
        # Itbayat is unserviceable even if a caller tampers with the zone field.
        if 'itbayat' in fields['city'].lower() or 'batanes' in fields['province'].lower():
            fields['zone'] = 'Unserviceable'
        addresses = self.list(db, 'address', owner)
        is_default = body.get('default', False) is True or not addresses
        if id and any(a['id'] == id and a['default'] for a in addresses):
            require(is_default, 'Make another address default first.')
        if is_default:
            for a in addresses:
                a['default'] = False
                self.put(db, 'address', a, owner)
        return self.put(db, 'address', dict(fields, id=id or secrets.token_hex(12), default=is_default), owner)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Do not write URLs, credentials, tokens, or request bodies to the log.
        pass

    def handle_request(self):
        try:
            length = int(self.headers.get('Content-Length', 0))
            require(0 <= length <= 36 * 1024 * 1024, 'Request is too large.', 413)
            body = json.loads(self.rfile.read(length)) if length else {}
            result = self.server.store.dispatch(self.command, self.path, body,
                self.headers.get('Authorization', '').removeprefix('Bearer '))
            self.respond(200, result)
        except Problem as e:
            self.respond(e.status, {'message': e.message})
        except (json.JSONDecodeError, ValueError, TypeError):
            self.respond(400, {'message': 'Invalid request. Check your fields and try again.'})
        except Exception:
            self.respond(500, {'message': 'The server could not complete the request. Please try again.'})

    def respond(self, status, result):
        raw = json.dumps(result).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(raw)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(raw)

    do_GET = do_POST = do_PATCH = do_DELETE = handle_request


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', default='127.0.0.1')
    parser.add_argument('--port', type=int, default=8000)
    parser.add_argument('--database', default=str(Path(__file__).with_name('buyer.sqlite3')))
    parser.add_argument('--storage', choices=('sqlite', 'mysql'), default='sqlite')
    parser.add_argument('--check', action='store_true', help='Validate the selected database without starting HTTP')
    parser.add_argument('--setup-mobile', action='store_true', help='Add mobile wishlist and notification read-state tables')
    args = parser.parse_args()
    if args.storage == 'mysql':
        # Share Problem/validation helpers when this file is executed as __main__.
        sys.modules.setdefault('server', sys.modules[__name__])
        from mysql_store import MySQLStore
        store = MySQLStore()
        if args.setup_mobile:
            store.setup_mobile()
            print('Mobile support tables are ready. Existing marketplace tables were not replaced.')
            sys.exit(0)
        try:
            result = store.check()
        except Exception as error:
            code = error.args[0] if error.args and isinstance(error.args[0], int) else None
            print(f'MySQL connection check failed (code {code or "configuration"}). Check backend/.env.mysql, MySQL service and schema.', file=sys.stderr)
            sys.exit(1)
        if args.check:
            print(json.dumps(result))
            sys.exit(0)
    else:
        store = Store(args.database)
        if args.check:
            print(json.dumps({'status': 'ok', 'storage': 'sqlite'}))
            sys.exit(0)
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    server.store = store
    print(f'Lumear buyer API ready: http://{args.host}:{args.port}/api', flush=True)
    server.serve_forever()
