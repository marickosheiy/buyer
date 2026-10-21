"""Adapter for the supplied Lumear MySQL schema. Never imports/seeds/migrates it."""
import hashlib
import base64
import json
import os
import re
import secrets
import ssl
import threading
import time
from contextlib import contextmanager
from datetime import date, datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

import bcrypt
import pymysql
from pymysql.cursors import DictCursor

from server import Problem, require, text, integer
from mobile_auth import MobileAuth


def settings(path=None):
    values = {}
    path = Path(path or Path(__file__).with_name('.env.mysql'))
    if path.exists():
        for line in path.read_text(encoding='utf-8-sig').splitlines():
            if line.strip() and not line.lstrip().startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                value = value.strip()
                if len(value) >= 2 and value[0] == value[-1] and value[0] in ('\"', "'"):
                    value = value[1:-1]
                values[key.strip()] = value
    for key in ('MYSQL_HOST', 'MYSQL_PORT', 'MYSQL_DATABASE', 'MYSQL_USER',
                'MYSQL_PASSWORD', 'MYSQL_SHIPPING_FEE_MINOR', 'SMTP_HOST', 'SMTP_PORT',
                'SMTP_USERNAME', 'SMTP_PASSWORD', 'SMTP_FROM', 'EMAIL_OTP_SECRET',
                'MYSQL_SSL_CA', 'MYSQL_SSL_CA_PEM', 'MYSQL_SSL_REQUIRED', 'PRIVATE_UPLOAD_ROOT',
                'PRIVATE_UPLOAD_STORAGE'):
        if key in os.environ:
            values[key] = os.environ[key]
    return values


def timestamp(value):
    if isinstance(value, datetime):
        return int(value.replace(tzinfo=timezone.utc).timestamp())
    return 0


def decode(value):
    return json.loads(value) if isinstance(value, (str, bytes)) else value


class MySQLStore:
    def __init__(self, config=None):
        self.config = config if config is not None else settings()
        self.auth = MobileAuth((lambda: self.config) if config is not None else settings)
        self.code_tag = hashlib.sha256(b''.join(Path(__file__).with_name(n).read_bytes() for n in ('mysql_store.py','mobile_auth.py','server.py'))).hexdigest()[:12]
        self.sessions = {}
        self.lock = threading.RLock()
        self.attempts = {}
        # Equal-cost failure for unknown accounts; never print or return hashes.
        self.dummy_hash = bcrypt.hashpw(secrets.token_bytes(32), bcrypt.gensalt())

    def setup_mobile(self):
        sql = Path(__file__).with_name('mobile_schema.sql').read_text()
        sql = '\n'.join(line for line in sql.splitlines() if not line.lstrip().startswith('--'))
        with self.transaction() as db:
            for statement in sql.split(';'):
                if statement.strip(): db.execute(statement)

    @contextmanager
    def transaction(self):
        c = self.config
        tls = None
        if c.get('MYSQL_SSL_REQUIRED', '').lower() in ('1', 'true') or c.get('MYSQL_SSL_CA') or c.get('MYSQL_SSL_CA_PEM'):
            tls = ssl.create_default_context(cafile=c.get('MYSQL_SSL_CA') or None,
                                             cadata=c.get('MYSQL_SSL_CA_PEM', '').replace('\\n', '\n') or None)
        db = pymysql.connect(host=c.get('MYSQL_HOST', '127.0.0.1'),
            port=int(c.get('MYSQL_PORT', '3306')), user=c.get('MYSQL_USER', 'root'),
            password=c.get('MYSQL_PASSWORD', ''), database=c.get('MYSQL_DATABASE', 'lumear_clean_dev'),
            charset='utf8mb4', cursorclass=DictCursor, autocommit=False,
            connect_timeout=5, read_timeout=15, write_timeout=15,
            init_command="SET time_zone = '+00:00'", ssl=tls)
        try:
            yield db.cursor()
            db.commit()
        except Exception:
            db.rollback()
            raise
        finally:
            db.close()

    @staticmethod
    def rows(db, sql, args=()):
        db.execute(sql, args)
        return list(db.fetchall())

    @staticmethod
    def one(db, sql, args=()):
        db.execute(sql, args)
        return db.fetchone()

    def check(self):
        required = {'users', 'sellers', 'products', 'product_variants', 'addresses',
                    'carts', 'cart_items', 'orders', 'seller_orders', 'order_items',
                    'wallet_accounts', 'wallet_journals', 'seller_payout_requests',
                    'roles', 'role_user', 'categories', 'order_timelines',
                    'inventory_movements', 'idempotency_keys', 'two_factor_credentials',
                    'mobile_wishlists', 'mobile_notification_reads', 'email_otp_codes'}
        if self.config.get('PRIVATE_UPLOAD_STORAGE') == 'mysql':
            required.add('mobile_private_documents')
        with self.transaction() as db:
            tables = {r['TABLE_NAME'] for r in self.rows(db,
                'SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE()')}
            missing = sorted(required - tables)
            require(not missing, 'Missing required tables: ' + ', '.join(missing), 503)
            return {'status': 'ok', 'application': 'lumear_mobile', 'code_tag': self.code_tag, 'database_tag': hashlib.sha256(self.config.get('MYSQL_DATABASE','').encode()).hexdigest()[:12], 'storage': 'mysql', 'schema_tables': len(tables),
                    'checkout_enabled': self.config.get('MYSQL_SHIPPING_FEE_MINOR', '') != ''}

    def identity(self, db, token):
        digest = hashlib.sha256(token.encode()).hexdigest()
        now = time.time()
        with self.lock:
            session = self.sessions.get(digest)
            require(session and now - session['touched'] < 1800, 'Your session expired. Please sign in again.', 401)
            session['touched'] = now
            uid = session['user_id']
        user = self.one(db, 'SELECT id,name,email,phone,is_suspended,password,email_verified_at FROM users WHERE id=%s', (uid,))
        require(user and not user['is_suspended'], 'Account unavailable.', 401)
        require(user['email_verified_at'], 'Verify your email before signing in.', 401)
        require(session['password_version'] == hashlib.sha256(user['password'].encode()).hexdigest(),
                'Your password changed. Please sign in again.', 401)
        require(not self.one(db, 'SELECT id FROM two_factor_credentials WHERE user_id=%s AND confirmed_at IS NOT NULL', (uid,)),
                'This account requires the original two-factor sign-in workflow.', 401)
        seller = self.one(db, 'SELECT * FROM sellers WHERE user_id=%s', (uid,))
        roles = {r['name'].lower() for r in self.rows(db,
            'SELECT r.name FROM roles r JOIN role_user ru ON ru.role_id=r.id WHERE ru.user_id=%s', (uid,))}
        require(seller or roles.intersection({'buyer', 'customer'}), 'This account has no buyer or seller access.', 403)
        return dict(id=str(uid), name=user['name'], email=user['email'], phone=user['phone'] or '',
                    role='seller' if seller else 'buyer'), seller

    def password_user(self, db, body):
        email = text(body.get('email'), 'Email', 3, 254).lower()
        password = body.get('password')
        require(isinstance(password, str) and 1 <= len(password.encode()) <= 72, 'Enter your password (up to 72 bytes).')
        with self.lock:
            failures = [t for t in self.attempts.get(email, []) if time.time() - t < 300]
            require(len(failures) < 10, 'Too many login attempts. Try again in five minutes.', 429)
        user = self.one(db, 'SELECT id,password,is_suspended,email_verified_at FROM users WHERE email=%s', (email,))
        stored = user['password'].encode() if user else self.dummy_hash
        try:
            valid = bcrypt.checkpw(password.encode(), stored)
        except ValueError:
            valid = False
        if not user or not valid or user['is_suspended']:
            with self.lock:
                self.attempts[email] = failures + [time.time()]
            raise Problem('Invalid email or password, or account unavailable.', 401)
        return user

    def login(self, db, body):
        user = self.password_user(db, body)
        if not user['email_verified_at']:
            return {'requires_email_verification': True, 'email': body['email'].strip().lower()}
        return self.issue_session(db, user)

    def issue_session(self, db, user):
        require(not user['is_suspended'], 'Account unavailable.', 401)
        require(not self.one(db, 'SELECT id FROM two_factor_credentials WHERE user_id=%s AND confirmed_at IS NOT NULL', (user['id'],)),
                'This account uses two-factor authentication. Its mobile sign-in adapter is not configured.', 503)
        token = secrets.token_urlsafe(32)
        digest = hashlib.sha256(token.encode()).hexdigest()
        with self.lock:
            self.sessions = {k: v for k, v in self.sessions.items() if time.time() - v['touched'] < 1800}
            self.sessions[digest] = {'user_id': user['id'], 'touched': time.time(),
                'password_version': hashlib.sha256(user['password'].encode()).hexdigest()}
            # A successful sign-in clears only this account's failed attempts.
            email_row = self.one(db, 'SELECT email FROM users WHERE id=%s', (user['id'],))
            self.attempts.pop(email_row['email'].lower(), None)
        try:
            profile, _ = self.identity(db, token)
        except Exception:
            with self.lock:
                self.sessions.pop(digest, None)
            raise
        return dict(profile, token=token)

    def register(self, db, body):
        email = text(body.get('email'), 'Email', 3, 254).lower()
        require(re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', email), 'Enter a valid email address.')
        password = body.get('password', '')
        require(isinstance(password, str) and 8 <= len(password.encode()) <= 72,
                'Password must be 8 to 72 bytes.')
        require(all(re.search(p, password) for p in ('[A-Z]', '[a-z]', '[0-9]')),
                'Use uppercase, lowercase and a number in your password.')
        name = text(body.get('name'), 'Name', 2, 100)
        phone = text(body.get('phone'), 'Phone', 11, 13)
        require(re.fullmatch(r'(09\d{9}|\+639\d{9})', phone), 'Enter a valid Philippine mobile number.')
        try:
            born = date.fromisoformat(body.get('date_of_birth', ''))
        except (TypeError, ValueError):
            raise Problem('Enter a valid date of birth.')
        today = date.today()
        age = today.year - born.year - ((today.month, today.day) < (born.month, born.day))
        require(18 <= age <= 120, 'You must be at least 18 years old.')
        account_type = body.get('account_type', 'buyer').lower()
        require(account_type in ('buyer', 'seller'), 'Choose a buyer or seller account.')
        self.auth.consume(db, email, body.get('verification_token'))
        role = self.one(db, 'SELECT id FROM roles WHERE LOWER(name)=%s', (account_type,))
        require(role, 'This account role is not configured in the database.', 503)
        require(not self.one(db, 'SELECT id FROM users WHERE email=%s', (email,)), 'Email already registered.')
        hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode().replace('$2b$', '$2y$', 1)
        db.execute('INSERT INTO users(name,email,password,phone,email_verified_at,created_at,updated_at) VALUES(%s,%s,%s,%s,UTC_TIMESTAMP(),UTC_TIMESTAMP(),UTC_TIMESTAMP())',
                   (name, email, hashed, phone))
        uid = db.lastrowid
        db.execute('INSERT INTO role_user(role_id,user_id) VALUES(%s,%s)', (role['id'], uid))
        if account_type == 'seller':
            shop_name = text(body.get('shop_name'), 'Shop name', 2, 100)
            shop_description = text(body.get('shop_description'), 'Shop description', 2, 1000)
            documents = body.get('documents')
            require(isinstance(documents, dict), 'Attach the required seller documents.')
            decoded = {}
            for kind in ('id', 'selfie', 'business'):
                f = documents.get(kind)
                require(isinstance(f, dict), 'Attach all three seller documents.')
                try:
                    raw = base64.b64decode(f.get('data', ''), validate=True)
                except (ValueError, TypeError):
                    raise Problem('Invalid document data.')
                require(0 < len(raw) <= 5*1024*1024, 'Documents must be at most 5 MB each.')
                extension = '.pdf' if raw.startswith(b'%PDF-') else '.png' if raw.startswith(b'\x89PNG\r\n\x1a\n') else '.jpg' if raw.startswith(b'\xff\xd8\xff') else None
                require(extension and (kind != 'selfie' or extension != '.pdf'), 'Use JPG or PNG for the selfie; other documents can also be PDF.')
                decoded[kind] = (raw, extension)
            slug = (re.sub(r'[^a-z0-9]+', '-', shop_name.lower()).strip('-') or 'shop') + '-' + secrets.token_hex(6)
            db.execute("INSERT INTO sellers(user_id,name,slug,description,status,created_at,updated_at) VALUES(%s,%s,%s,%s,'active',UTC_TIMESTAMP(),UTC_TIMESTAMP())", (uid, shop_name, slug, shop_description))
            sid = db.lastrowid
            upload_root = Path(self.config.get('PRIVATE_UPLOAD_ROOT', str(Path(__file__).with_name('private_uploads'))))
            directory = upload_root / 'seller-kyc' / str(sid)
            database_uploads = self.config.get('PRIVATE_UPLOAD_STORAGE') == 'mysql'
            if not database_uploads:
                directory.mkdir(parents=True, exist_ok=True)
            paths = {}
            for kind, (raw, extension) in decoded.items():
                target = directory / (secrets.token_hex(16) + extension)
                paths[kind] = target.relative_to(upload_root).as_posix()
                if database_uploads:
                    db.execute('INSERT INTO mobile_private_documents(storage_key,content) VALUES(%s,%s)', (paths[kind], raw))
                else:
                    target.write_bytes(raw)
            db.execute("INSERT INTO seller_kyc_submissions(seller_id,government_id_path,selfie_path,business_permit_path,status,submitted_at,created_at,updated_at) VALUES(%s,%s,%s,%s,'pending',UTC_TIMESTAMP(),UTC_TIMESTAMP(),UTC_TIMESTAMP())", (sid, paths['id'], paths['selfie'], paths['business']))
            db.execute('INSERT INTO seller_profiles(seller_id,business_name,created_at,updated_at) VALUES(%s,%s,UTC_TIMESTAMP(),UTC_TIMESTAMP())', (sid, shop_name))
        return {'message': 'Account created and email verified.', 'account_type': account_type,
                'seller_status': 'active' if account_type == 'seller' else None}

    def catalog(self, db, seller_id=None):
        where = 'p.deleted_at IS NULL'
        args = ()
        if seller_id is None:
            where += " AND p.is_active=1 AND p.moderation_status='active' AND s.status IN ('active','approved') AND c.is_active=1"
        else:
            where += ' AND p.seller_id=%s'
            args = (seller_id,)
        products = self.rows(db, f'''SELECT p.*,s.name store,s.status seller_status,c.name category
            FROM products p JOIN sellers s ON s.id=p.seller_id JOIN categories c ON c.id=p.category_id
            WHERE {where} ORDER BY p.id DESC''', args)
        result = []
        for p in products:
            variants = self.rows(db, 'SELECT * FROM product_variants WHERE product_id=%s AND deleted_at IS NULL ORDER BY id', (p['id'],))
            if seller_id is None:
                variants = [v for v in variants if v['is_active']]
            reviews = self.rows(db, 'SELECT rating,body,created_at FROM product_reviews WHERE product_id=%s', (p['id'],))
            result.append(dict(id=str(p['id']), name=p['name'], description=p['description'],
                seller=str(p['seller_id']), store=p['store'], category=p['category'],
                category_id=str(p['category_id']), active=bool(p['is_active']),
                approved=p['moderation_status'] == 'active', moderation=p['moderation_status'],
                price=min((v['price_minor'] for v in variants), default=0),
                stock=sum(v['stock'] for v in variants), limit=99999, vacation=False,
                variants=[dict(id=str(v['id']), label=v['name'], price=v['price_minor'], stock=v['stock'],
                               active=bool(v['is_active']), grams=v.get('weight_grams',0)) for v in variants],
                review_count=len(reviews), rating=sum(r['rating'] for r in reviews) / len(reviews) if reviews else 0,
                reviews=[dict(reviewer='Buyer', stars=r['rating'], text=r['body'] or '', photos=[], date=timestamp(r['created_at'])) for r in reviews]))
        return result

    def addresses(self, db, uid):
        return [dict(id=str(a['id']), label=a['label'], name=a['recipient'], phone=a['phone'],
            street=a['line1'], barangay=a['barangay'], city=a['city'], province=a['province'],
            postal_code=a['postal_code'], default=bool(a['is_default']))
            for a in self.rows(db, 'SELECT * FROM addresses WHERE user_id=%s ORDER BY is_default DESC,id', (uid,))]

    def save_address(self, db, uid, body, aid=None):
        # Lock the parent to serialize default/address-limit changes for one buyer.
        self.one(db, 'SELECT id FROM users WHERE id=%s FOR UPDATE', (uid,))
        addresses = self.addresses(db, uid)
        old = next((a for a in addresses if a['id'] == aid), None)
        require(aid is None or old, 'Address not found.', 404)
        require(aid is not None or len(addresses) < 10, 'You can save up to 10 addresses.')
        a = dict(old or {}, **body)
        for key in ('label', 'name', 'phone', 'street', 'barangay', 'city', 'province', 'postal_code'):
            a[key] = text(a.get(key), key.replace('_', ' ').title(), 1, 150)
        require(re.fullmatch(r'(09\d{9}|\+639\d{9})', a['phone']), 'Enter a valid Philippine mobile number.')
        default = a.get('default') is True or not addresses
        require(not old or not old['default'] or default, 'Make another address default first.')
        if default:
            db.execute('UPDATE addresses SET is_default=0,updated_at=UTC_TIMESTAMP() WHERE user_id=%s', (uid,))
        values = (a['label'], a['name'], a['phone'], a['street'], a['barangay'], a['city'], a['province'], a['postal_code'], default)
        if aid:
            db.execute('UPDATE addresses SET label=%s,recipient=%s,phone=%s,line1=%s,barangay=%s,city=%s,province=%s,postal_code=%s,is_default=%s,updated_at=UTC_TIMESTAMP() WHERE id=%s AND user_id=%s', values + (aid, uid))
        else:
            db.execute('INSERT INTO addresses(label,recipient,phone,line1,barangay,city,province,postal_code,is_default,user_id,created_at,updated_at) VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,UTC_TIMESTAMP(),UTC_TIMESTAMP())', values + (uid,))
            aid = str(db.lastrowid)
        return next(a for a in self.addresses(db, uid) if a['id'] == aid)

    def cart(self, db, uid):
        return [dict(id=str(r['id']), product_id=str(r['product_id']), variant_id=str(r['product_variant_id']),
            name=r['name'], variant=r['variant'], quantity=r['quantity'], price=r['price_minor'],
            store=r['store'], selected=bool(r['selected'])) for r in self.rows(db, '''
            SELECT ci.*,v.product_id,v.name variant,v.price_minor,p.name,s.name store
            FROM cart_items ci JOIN carts c ON c.id=ci.cart_id JOIN product_variants v ON v.id=ci.product_variant_id
            JOIN products p ON p.id=v.product_id JOIN sellers s ON s.id=p.seller_id WHERE c.user_id=%s ORDER BY ci.id''', (uid,))]

    def mutate_cart(self, db, uid, method, body, cid=None):
        self.one(db, 'SELECT id FROM users WHERE id=%s FOR UPDATE', (uid,))
        cart = self.one(db, 'SELECT id FROM carts WHERE user_id=%s', (uid,))
        if not cart:
            require(method == 'POST' and cid is None, 'Cart item not found.', 404)
            db.execute('INSERT INTO carts(user_id,created_at,updated_at) VALUES(%s,UTC_TIMESTAMP(),UTC_TIMESTAMP())', (uid,))
            cart = {'id': db.lastrowid}
        item = self.one(db, 'SELECT * FROM cart_items WHERE id=%s AND cart_id=%s', (cid, cart['id'])) if cid else None
        require(cid is None or item, 'Cart item not found.', 404)
        if method == 'DELETE':
            require(item, 'Cart item not found.', 404)
            db.execute('DELETE FROM cart_items WHERE id=%s AND cart_id=%s', (cid, cart['id']))
            return {'message': 'Item removed.'}
        qty = integer(body.get('quantity'), 'Quantity')
        vid = item['product_variant_id'] if item else body.get('variant_id')
        v = self.one(db, '''SELECT v.*,p.is_active product_active,p.deleted_at product_deleted,
            p.moderation_status,s.status seller_status FROM product_variants v JOIN products p ON p.id=v.product_id
            JOIN sellers s ON s.id=p.seller_id WHERE v.id=%s FOR UPDATE''', (vid,))
        require(v and v['is_active'] and not v['deleted_at'] and v['product_active'] and not v['product_deleted']
                and v['moderation_status'] == 'active' and v['seller_status'] in ('active', 'approved'), 'Product unavailable.')
        if not item:
            require(str(v['product_id']) == str(body.get('product_id')), 'Variant does not belong to this product.')
            item = self.one(db, 'SELECT * FROM cart_items WHERE cart_id=%s AND product_variant_id=%s', (cart['id'], vid))
            if item:
                qty += item['quantity']
        require(qty <= v['stock'] and qty <= 99999, 'Quantity exceeds available stock or purchase limit.')
        if item:
            cid = str(item['id'])
            db.execute('UPDATE cart_items SET quantity=%s,updated_at=UTC_TIMESTAMP() WHERE id=%s', (qty, cid))
        else:
            db.execute('INSERT INTO cart_items(cart_id,product_variant_id,quantity,selected,created_at,updated_at) VALUES(%s,%s,%s,1,UTC_TIMESTAMP(),UTC_TIMESTAMP())', (cart['id'], vid, qty))
            cid = str(db.lastrowid)
        return next(i for i in self.cart(db, uid) if i['id'] == cid)

    def orders(self, db, uid=None, sid=None):
        condition, args = ('o.buyer_id=%s', (uid,)) if sid is None else ('so.seller_id=%s', (sid,))
        rows = self.rows(db, f'''SELECT so.*,o.reference,o.buyer_id,o.shipping_address,o.payment_method,o.payment_status,
            u.name buyer,s.name store FROM seller_orders so JOIN orders o ON o.id=so.order_id
            JOIN users u ON u.id=o.buyer_id JOIN sellers s ON s.id=so.seller_id WHERE {condition} ORDER BY so.id DESC''', args)
        result = []
        for o in rows:
            items = self.rows(db, 'SELECT * FROM order_items WHERE seller_order_id=%s ORDER BY id', (o['id'],))
            address = decode(o['shipping_address']) or {}
            timelines = self.rows(db, 'SELECT status,event,note,created_at FROM order_timelines WHERE seller_order_id=%s ORDER BY id', (o['id'],))
            result.append(dict(id=str(o['id']), reference=o['reference'], seller=str(o['seller_id']),
                buyer=o['buyer'], store=o['store'], raw_status=o['status'],
                status={'pending': 'To Ship', 'accepted': 'To Ship', 'packed': 'To Ship', 'ready_to_ship': 'To Ship',
                        'shipped': 'To Receive', 'delivered': 'To Receive', 'completed': 'Completed', 'cancelled': 'Cancelled'}[o['status']],
                ready_for_pickup=o['status'] not in ('pending', 'accepted'),
                date=timestamp(o['created_at']), delivered_at=timestamp(o.get('delivered_at')),
                completed_at=timestamp(o['updated_at']) if o['status'] == 'completed' else None,
                payment_method=o['payment_method'].upper(), paid=o['payment_status'] == 'paid',
                subtotal=o['subtotal_minor'], shipping=o['shipping_fee_minor'], commission=o['commission_minor'],
                discount=0, total=o['subtotal_minor'] + o['shipping_fee_minor'],
                note=o['note'] or '', address=dict(name=address.get('recipient', address.get('name', '')),
                    phone=address.get('phone', ''), street=address.get('line1', address.get('street', '')),
                    city=address.get('city', ''), province=address.get('province', ''), **{'default': False}),
                timeline=[dict(title=t['event'] or t['status'], date=timestamp(t['created_at'])) for t in timelines],
                items=[dict(id=str(i['id']), product_id=str(i['product_id']), variant_id=str(i['product_variant_id']),
                    name=i['product_name'], variant=i['variant_name'], quantity=i['quantity'], price=i['unit_price_minor']) for i in items]))
        return result

    def request_payout(self, db, uid, sid, body):
        # Serialize requests with balance updates, without transferring money or
        # changing the existing wallet/settlement ledger.
        self.one(db, 'SELECT id FROM users WHERE id=%s FOR UPDATE', (uid,))
        wallet = self.one(db, 'SELECT * FROM wallet_accounts WHERE seller_id=%s FOR UPDATE', (sid,))
        require(wallet, 'Your shop does not have a wallet account yet.')
        amount = integer(body.get('amount'), 'Payout amount', 100, 2147483647)
        account_id = str(body.get('account_id', ''))
        account = self.one(db, 'SELECT id FROM seller_payout_accounts WHERE id=%s AND seller_id=%s', (account_id, sid))
        require(account, 'Choose one of your saved payout accounts.')
        key = text(body.get('idempotency_key'), 'Request key', 8, 120)
        scope = 'mobile-payout:' + str(sid)
        fingerprint = hashlib.sha256(json.dumps(dict(amount=amount, account_id=account_id), sort_keys=True).encode()).hexdigest()
        previous = self.one(db, 'SELECT request_hash FROM idempotency_keys WHERE scope=%s AND `key`=%s FOR UPDATE', (scope, key))
        if previous:
            require(previous['request_hash'] == fingerprint, 'This request key was already used for another payout.', 409)
            return {'message': 'Payout request received for manual review.'}
        pending = self.one(db, "SELECT COALESCE(SUM(amount_minor),0) amount FROM seller_payout_requests WHERE seller_id=%s AND paid_at IS NULL AND status NOT IN ('rejected','cancelled','failed','paid')", (sid,))
        require(amount <= max(0, int(wallet['balance_minor']) - int(pending['amount'])), 'This exceeds your available balance after open payout requests.', 409)
        db.execute("INSERT INTO seller_payout_requests(seller_id,seller_payout_account_id,amount_minor,status,created_at,updated_at) VALUES(%s,%s,%s,'requested',UTC_TIMESTAMP(),UTC_TIMESTAMP())", (sid, account_id, amount))
        db.execute('INSERT INTO idempotency_keys(scope,`key`,request_hash) VALUES(%s,%s,%s)', (scope, key, fingerprint))
        return {'message': 'Payout request received for manual review.'}

    def earnings(self, db, sid):
        totals = self.one(db, '''SELECT COALESCE(SUM(CASE WHEN status='completed' THEN subtotal_minor ELSE 0 END),0) gross,
            COALESCE(SUM(CASE WHEN status='completed' THEN commission_minor ELSE 0 END),0) fees,
            COALESCE(SUM(CASE WHEN status NOT IN ('completed','cancelled') THEN subtotal_minor ELSE 0 END),0) pending_sales
            FROM seller_orders WHERE seller_id=%s''', (sid,))
        wallet = self.one(db, 'SELECT * FROM wallet_accounts WHERE seller_id=%s', (sid,))
        payouts = self.rows(db, 'SELECT id,amount_minor,status,paid_at,created_at FROM seller_payout_requests WHERE seller_id=%s ORDER BY id DESC', (sid,))
        accounts = self.rows(db, 'SELECT id,type,account_name,is_default FROM seller_payout_accounts WHERE seller_id=%s ORDER BY is_default DESC,id', (sid,))
        reserved = sum(int(p['amount_minor']) for p in payouts if p['paid_at'] is None and p['status'] not in ('rejected','cancelled','failed','paid'))
        journals = self.rows(db, '''SELECT j.id,j.type,j.amount_minor,j.description,j.created_at
            FROM wallet_journals j JOIN wallet_accounts w ON w.id=j.wallet_account_id WHERE w.seller_id=%s ORDER BY j.id DESC LIMIT 100''', (sid,))
        return dict(gross_sales=int(totals['gross']), fees=int(totals['fees']),
            net_sales=int(totals['gross']) - int(totals['fees']), pending_sales=int(totals['pending_sales']),
            wallet_available=int(wallet['balance_minor']) if wallet else None,
            available_to_request=max(0, int(wallet['balance_minor']) - reserved) if wallet else None,
            payout_accounts=[dict(id=str(a['id']), type=a['type'], name=a['account_name'], default=bool(a['is_default'])) for a in accounts],
            wallet_pending=None,
            paid_out=sum(int(p['amount_minor']) for p in payouts if p['paid_at'] is not None),
            payouts=[dict(id=str(p['id']), amount=int(p['amount_minor']), status=p['status'], date=timestamp(p['created_at'])) for p in payouts],
            journals=[dict(id=str(j['id']), type=j['type'], amount=int(j['amount_minor']),
                reference=j['description'] or '', date=timestamp(j['created_at'])) for j in journals])

    def seller_snapshot(self, db, user, seller):
        return dict(shop=dict(owner=user['name'], email=user['email'], phone=user['phone'],
            name=seller['name'], description=seller['description'] or '', status=seller['status']),
            products=self.catalog(db, seller['id']), orders=self.orders(db, sid=seller['id']),
            earnings=self.earnings(db, seller['id']),
            categories=[dict(id=str(c['id']), name=c['name']) for c in self.rows(db, 'SELECT id,name FROM categories WHERE is_active=1 ORDER BY name')])

    def capabilities(self):
        return dict(storage='mysql', addresses=True, checkout=self.config.get('MYSQL_SHIPPING_FEE_MINOR', '') != '',
            wishlist=True, follows=False, vouchers=False, notifications=True, returns=False,
            reviews=False, chat=False, profile_photos=False, receipt_confirmation=False)

    def notifications(self, db, uid):
        rows = self.rows(db, '''SELECT t.id,t.event,t.status,t.note,t.created_at,o.reference,r.read_at
            FROM order_timelines t JOIN orders o ON o.id=t.order_id
            LEFT JOIN mobile_notification_reads r ON r.timeline_id=t.id AND r.user_id=%s
            WHERE o.buyer_id=%s ORDER BY t.id DESC LIMIT 100''', (uid, uid))
        return [dict(id=str(r['id']), title=r['event'] or r['status'], message=r['note'] or r['reference'],
            date=timestamp(r['created_at']), read=r['read_at'] is not None) for r in rows]

    def buyer_snapshot(self, db, user):
        uid = user['id']
        return dict(profile=user, products=self.catalog(db), cart=self.cart(db, uid), orders=self.orders(db, uid),
            addresses=self.addresses(db, uid), capabilities=self.capabilities(), vouchers=[], follows=[],
            wishlist=[dict(id=str(r['product_id'])) for r in self.rows(db, 'SELECT product_id FROM mobile_wishlists WHERE user_id=%s', (uid,))],
            notifications=self.notifications(db, uid))

    def inventory(self, db, variant, delta, actor, order_id=None, kind='adjustment'):
        after = variant['stock'] + delta
        require(after >= 0, 'Insufficient stock.', 409)
        db.execute('UPDATE product_variants SET stock=%s,updated_at=UTC_TIMESTAMP() WHERE id=%s', (after, variant['id']))
        db.execute('''INSERT INTO inventory_movements(product_variant_id,seller_order_id,actor_id,type,quantity_delta,stock_after,created_at,updated_at)
            VALUES(%s,%s,%s,%s,%s,%s,UTC_TIMESTAMP(),UTC_TIMESTAMP())''', (variant['id'], order_id, actor, kind, delta, after))

    def timeline(self, db, order, actor, status, event, note=''):
        db.execute('''INSERT INTO order_timelines(order_id,seller_order_id,actor_id,status,event,note,created_at,updated_at)
            VALUES(%s,%s,%s,%s,%s,%s,UTC_TIMESTAMP(),UTC_TIMESTAMP())''', (order['order_id'], order['id'], actor, status, event, note))

    def cancel_order(self, db, uid, oid, body, sid=None):
        # Consistent lock order: user -> seller order -> inventory.
        self.one(db, 'SELECT id FROM users WHERE id=%s FOR UPDATE', (uid,))
        condition, args = ('o.buyer_id=%s', (uid,)) if sid is None else ('so.seller_id=%s', (sid,))
        o = self.one(db, f'''SELECT so.*,o.payment_status FROM seller_orders so JOIN orders o ON o.id=so.order_id
            WHERE so.id=%s AND {condition} FOR UPDATE''', (oid,) + args)
        require(o, 'Order not found.', 404)
        if o['status'] == 'cancelled':
            return {'message': 'Order already cancelled.'}
        require(o['status'] in ('pending', 'accepted'), 'Only orders that have not been packed can be cancelled.')
        require(o['payment_status'] == 'pending', 'Paid orders require the existing refund workflow.')
        require(not self.one(db, 'SELECT id FROM wallet_journals WHERE seller_order_id=%s LIMIT 1', (oid,)),
                'This order has wallet entries and requires the original settlement workflow.')
        reason = text(body.get('reason'), 'Cancellation reason', 3, 300)
        items = self.rows(db, 'SELECT product_variant_id,SUM(quantity) quantity FROM order_items WHERE seller_order_id=%s GROUP BY product_variant_id ORDER BY product_variant_id', (oid,))
        for item in items:
            movement = self.one(db, 'SELECT COALESCE(SUM(quantity_delta),0) delta FROM inventory_movements WHERE seller_order_id=%s AND product_variant_id=%s', (oid, item['product_variant_id']))
            require(-int(movement['delta']) == int(item['quantity']),
                    'Inventory history does not confirm this reservation. Use the original order management workflow.')
            v = self.one(db, 'SELECT id,stock FROM product_variants WHERE id=%s FOR UPDATE', (item['product_variant_id'],))
            self.inventory(db, v, int(item['quantity']), uid, oid, 'cancellation')
        db.execute("UPDATE seller_orders SET status='cancelled',updated_at=UTC_TIMESTAMP() WHERE id=%s", (oid,))
        self.timeline(db, o, uid, 'cancelled', 'Order cancelled', reason)
        return {'message': 'Order cancelled.'}

    def quote(self, db, uid, body):
        rate = self.config.get('MYSQL_SHIPPING_FEE_MINOR', '')
        require(rate != '', 'Checkout is awaiting a configured shipping rate.', 503)
        require(str(rate).isdigit() and 0 <= int(rate) <= 10000000, 'Invalid backend shipping configuration.', 503)
        require(not body.get('vouchers'), 'Vouchers are not configured in this database.')
        address = next((a for a in self.addresses(db, uid) if a['id'] == str(body.get('address_id'))), None)
        require(address, 'Select one of your saved addresses.')
        items = [i for i in self.cart(db, uid) if i['selected']]
        require(items, 'Your cart is empty.')
        groups = {}
        for item in sorted(items, key=lambda i: int(i['variant_id'])):
            v = self.one(db, '''SELECT v.*,p.name product_name,p.seller_id,p.is_active product_active,
                p.deleted_at product_deleted,p.moderation_status,s.name store,s.status seller_status
                FROM product_variants v JOIN products p ON p.id=v.product_id JOIN sellers s ON s.id=p.seller_id
                WHERE v.id=%s FOR UPDATE''', (item['variant_id'],))
            require(v and v['is_active'] and not v['deleted_at'] and v['product_active'] and not v['product_deleted']
                    and v['moderation_status'] == 'active' and v['seller_status'] in ('active', 'approved'), 'An item is no longer available.', 409)
            require(0 < item['quantity'] <= v['stock'], 'Stock changed. Update your cart.', 409)
            item.update(price=v['price_minor'], name=v['product_name'])
            g = groups.setdefault(str(v['seller_id']), dict(seller=str(v['seller_id']), store=v['store'],
                items=[], subtotal=0, shipping=int(rate), discount=0))
            g['items'].append(item)
            g['subtotal'] += v['price_minor'] * item['quantity']
        for g in groups.values():
            g['total'] = g['subtotal'] + g['shipping']
        return dict(address=address, stores=list(groups.values()), discounts=[], total=sum(g['total'] for g in groups.values()))

    def checkout(self, db, uid, body):
        self.one(db, 'SELECT id FROM users WHERE id=%s FOR UPDATE', (uid,))
        key = text(body.get('idempotency_key'), 'Checkout request key', 8, 120)
        scope = 'mobile-checkout:' + uid
        fingerprint = hashlib.sha256(json.dumps(body, sort_keys=True).encode()).hexdigest()
        previous = self.one(db, 'SELECT * FROM idempotency_keys WHERE scope=%s AND `key`=%s FOR UPDATE', (scope, key))
        if previous:
            require(previous['request_hash'] == fingerprint, 'Checkout key already used for another request.', 409)
            orders = [o for o in self.orders(db, uid) if o['reference'] == self.one(db, 'SELECT reference FROM orders WHERE id=%s', (previous['order_id'],))['reference']]
            return {'orders': orders, 'total': sum(o['total'] for o in orders)}
        require(body.get('payment_method') == 'COD', 'Only COD checkout is enabled.')
        q = self.quote(db, uid, body)
        require(body.get('expected_quote') == q, 'Prices, stock or address changed. Review the total again.', 409)
        note = text(body.get('note', ''), 'Note', 0, 200)
        a = q['address']
        snapshot = dict(recipient=a['name'], phone=a['phone'], line1=a['street'], barangay=a['barangay'],
            city=a['city'], province=a['province'], postal_code=a['postal_code'])
        ref = 'LM' + secrets.token_hex(8).upper()
        db.execute("INSERT INTO orders(buyer_id,reference,total_minor,payment_method,payment_status,shipping_address,created_at,updated_at) VALUES(%s,%s,%s,'cod','pending',%s,UTC_TIMESTAMP(),UTC_TIMESTAMP())", (uid, ref, q['total'], json.dumps(snapshot)))
        order_id = db.lastrowid
        for group in q['stores']:
            s = self.one(db, 'SELECT commission_bps FROM sellers WHERE id=%s', (group['seller'],))
            require(0 <= s['commission_bps'] <= 10000, 'Invalid seller commission configuration.', 503)
            commission = (group['subtotal'] * s['commission_bps'] + 5000) // 10000
            db.execute("INSERT INTO seller_orders(order_id,seller_id,subtotal_minor,shipping_fee_minor,commission_minor,status,note,created_at,updated_at) VALUES(%s,%s,%s,%s,%s,'pending',%s,UTC_TIMESTAMP(),UTC_TIMESTAMP())", (order_id, group['seller'], group['subtotal'], group['shipping'], commission, note))
            soid = db.lastrowid
            for i in group['items']:
                v = self.one(db, 'SELECT id,stock FROM product_variants WHERE id=%s FOR UPDATE', (i['variant_id'],))
                self.inventory(db, v, -i['quantity'], uid, soid, 'reservation')
                db.execute('INSERT INTO order_items(seller_order_id,product_id,product_variant_id,product_name,variant_name,unit_price_minor,quantity,created_at,updated_at) VALUES(%s,%s,%s,%s,%s,%s,%s,UTC_TIMESTAMP(),UTC_TIMESTAMP())',
                    (soid, i['product_id'], i['variant_id'], i['name'], i['variant'], i['price'], i['quantity']))
                db.execute('DELETE ci FROM cart_items ci JOIN carts c ON c.id=ci.cart_id WHERE ci.id=%s AND c.user_id=%s', (i['id'], uid))
            self.timeline(db, dict(order_id=order_id, id=soid), uid, 'pending', 'Order placed')
        db.execute("INSERT INTO payments(order_id,method,amount_minor,status,created_at,updated_at) VALUES(%s,'cod',%s,'pending',UTC_TIMESTAMP(),UTC_TIMESTAMP())", (order_id, q['total']))
        db.execute('INSERT INTO idempotency_keys(scope,`key`,request_hash,order_id) VALUES(%s,%s,%s,%s)', (scope, key, fingerprint, order_id))
        return {'orders': [o for o in self.orders(db, uid) if o['reference'] == ref], 'total': q['total']}

    def save_product(self, db, uid, sid, body, pid=None):
        name = text(body.get('name'), 'Product name', 1, 100)
        description = text(body.get('description', ''), 'Description', 0, 1000)
        category = self.one(db, 'SELECT id FROM categories WHERE name=%s AND is_active=1', (text(body.get('category'), 'Category', 1, 100),))
        require(category, 'Choose an existing active category.')
        price = integer(body.get('price'), 'Price in centavos', 1, 999999999)
        stock = integer(body.get('stock'), 'Stock', 0, 999999)
        active = body.get('active', True)
        require(type(active) is bool, 'Listing visibility must be true or false.')
        if pid:
            p = self.one(db, 'SELECT * FROM products WHERE id=%s AND seller_id=%s AND deleted_at IS NULL FOR UPDATE', (pid, sid))
            require(p, 'Product not found.', 404)
            variants = self.rows(db, 'SELECT * FROM product_variants WHERE product_id=%s AND deleted_at IS NULL ORDER BY id FOR UPDATE', (pid,))
            require(len(variants) == 1, 'Products with multiple variants require variant-specific editing. Use the existing management tool.')
            v = variants[0]
            # Editing never changes a restricted listing's status or other variants.
            db.execute('UPDATE products SET name=%s,description=%s,category_id=%s,is_active=%s,updated_at=UTC_TIMESTAMP() WHERE id=%s', (name, description, category['id'], active, pid))
            db.execute('UPDATE product_variants SET price_minor=%s,updated_at=UTC_TIMESTAMP() WHERE id=%s', (price, v['id']))
            if stock != v['stock']:
                self.inventory(db, v, stock - v['stock'], uid)
        else:
            suffix = secrets.token_hex(6)
            slug = (re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-') or 'product') + '-' + suffix
            db.execute("INSERT INTO products(seller_id,category_id,name,slug,description,is_active,moderation_status,created_at,updated_at) VALUES(%s,%s,%s,%s,%s,%s,'active',UTC_TIMESTAMP(),UTC_TIMESTAMP())", (sid, category['id'], name, slug, description, active))
            pid = str(db.lastrowid)
            db.execute("INSERT INTO product_variants(product_id,sku,name,price_minor,stock,is_active,created_at,updated_at) VALUES(%s,%s,'Default',%s,0,1,UTC_TIMESTAMP(),UTC_TIMESTAMP())", (pid, 'MOB-' + suffix.upper(), price))
            self.inventory(db, dict(id=db.lastrowid, stock=0), stock, uid)
        return {'id': str(pid), 'message': 'Product saved.'}

    def dispatch(self, method, url, body=None, token=''):
        body = body or {}
        require(isinstance(body, dict), 'Send a JSON object.')
        path = urlparse(url).path.removeprefix('/api').rstrip('/')
        if path == '/health' and method == 'GET':
            return self.check()
        if path == '/auth/config' and method == 'GET':
            return self.auth.public_config()
        with self.transaction() as db:
            if path == '/auth/email/send' and method == 'POST':
                email = text(body.get('email'), 'Email',3,254).lower()
                purpose = body.get('purpose', 'registration')
                if purpose == 'registration':
                    require(not self.one(db, 'SELECT id FROM users WHERE email=%s', (email,)), 'This email already has an account. Sign in instead.')
                    return self.auth.send(db,email,purpose)
                require(purpose == 'account','Invalid verification purpose.')
                user = self.password_user(db,body)
                require(not user['email_verified_at'], 'Your email is already verified. Sign in instead.')
                return self.auth.send(db,email,purpose,user['id'])
            if path == '/auth/email/verify' and method == 'POST':
                return self.auth.verify(db,body)
            if path == '/auth/login' and method == 'POST':
                return self.login(db, body)
            if path == '/auth/register' and method == 'POST':
                return self.register(db, body)
            user, seller = self.identity(db, token)
            uid = user['id']
            if path == '/auth/logout' and method == 'POST':
                with self.lock:
                    self.sessions.pop(hashlib.sha256(token.encode()).hexdigest(), None)
                return {'message': 'Signed out.'}
            if path == '/capabilities' and method == 'GET':
                return self.capabilities()
            if path == '/me':
                if method == 'GET':
                    return user
                require(method == 'PATCH', 'Method not allowed.', 405)
                require(not body.get('photos'), 'Profile photo storage is not configured.')
                name = text(body.get('name'), 'Name', 2, 100)
                db.execute('UPDATE users SET name=%s,updated_at=UTC_TIMESTAMP() WHERE id=%s', (name, uid))
                return dict(user, name=name)
            if path == '/auth/password' and method == 'POST':
                row = self.one(db, 'SELECT password FROM users WHERE id=%s FOR UPDATE', (uid,))
                current = body.get('current_password', '')
                require(isinstance(current, str) and len(current.encode()) <= 72, 'Enter your current password.')
                require(bcrypt.checkpw(current.encode(), row['password'].encode()), 'Current password is incorrect.')
                new = body.get('new_password', '')
                require(isinstance(new, str) and 8 <= len(new.encode()) <= 72 and new == body.get('confirm_password'), 'Use a matching password of 8 to 72 bytes.')
                require(new != current and all(re.search(p, new) for p in ('[A-Z]', '[a-z]', '[0-9]', '[^A-Za-z0-9\\s]')), 'Use a new password with uppercase, lowercase, a number and a special character.')
                hashed = bcrypt.hashpw(new.encode(), bcrypt.gensalt()).decode().replace('$2b$', '$2y$', 1)
                db.execute('UPDATE users SET password=%s,remember_token=NULL,updated_at=UTC_TIMESTAMP() WHERE id=%s', (hashed, uid))
                # Revoke web sessions too, preserving neither stale web cookies nor old mobile sessions.
                db.execute('DELETE FROM sessions WHERE user_id=%s', (uid,))
                digest = hashlib.sha256(token.encode()).hexdigest()
                with self.lock:
                    self.sessions = {k: s for k, s in self.sessions.items() if str(s['user_id']) != uid or k == digest}
                    if digest in self.sessions:
                        self.sessions[digest]['password_version'] = hashlib.sha256(hashed.encode()).hexdigest()
                return {'message': 'Password changed. Other sessions revoked.'}
            if path.startswith('/seller/'):
                require(seller, 'Seller access required.', 403)
                sid = seller['id']
                if path == '/seller/workspace' and method == 'GET':
                    return self.seller_snapshot(db, user, seller)
                require(seller['status'] in ('active', 'approved'), 'Your shop is not active. Listing and order actions are unavailable.', 403)
                if path == '/seller/shop' and method == 'PATCH':
                    require(body.get('email', user['email']) == user['email'] and body.get('phone', user['phone']) == user['phone'], 'Verified contact changes are not configured.')
                    owner = text(body.get('owner'), 'Seller name', 2, 100)
                    name = text(body.get('name'), 'Shop name', 2, 100)
                    description = text(body.get('description', ''), 'Description', 0, 1000)
                    db.execute('UPDATE users SET name=%s,updated_at=UTC_TIMESTAMP() WHERE id=%s', (owner, uid))
                    db.execute('UPDATE sellers SET name=%s,description=%s,updated_at=UTC_TIMESTAMP() WHERE id=%s', (name, description, sid))
                    return {'message': 'Shop saved.'}
                if path == '/seller/payouts' and method == 'POST':
                    return self.request_payout(db, uid, sid, body)
                if path == '/seller/products' and method == 'POST':
                    return self.save_product(db, uid, sid, body)
                if re.fullmatch(r'/seller/products/\d+', path) and method == 'PATCH':
                    return self.save_product(db, uid, sid, body, path.split('/')[3])
                match = re.fullmatch(r'/seller/orders/(\d+)/(prepare|cancel)', path)
                if match and method == 'POST':
                    oid, action = match.groups()
                    if action == 'cancel':
                        return self.cancel_order(db, uid, oid, body, sid)
                    o = self.one(db, 'SELECT * FROM seller_orders WHERE id=%s AND seller_id=%s FOR UPDATE', (oid, sid))
                    require(o, 'Order not found.', 404)
                    if o['status'] == 'ready_to_ship':
                        return {'message': 'Already ready for pickup.'}
                    require(o['status'] in ('pending', 'accepted', 'packed'), 'This order cannot be prepared.')
                    db.execute("UPDATE seller_orders SET status='ready_to_ship',updated_at=UTC_TIMESTAMP() WHERE id=%s", (oid,))
                    self.timeline(db, o, uid, 'ready_to_ship', 'Ready for pickup')
                    return {'message': 'Order ready for pickup.'}
                raise Problem('Seller endpoint not available.', 404)
            require(user['role'] == 'buyer', 'Buyer access required.', 403)
            if path == '/buyer/workspace' and method == 'GET':
                return self.buyer_snapshot(db, user)
            if path == '/wishlist' and method == 'GET':
                return [dict(id=str(r['product_id'])) for r in self.rows(db, 'SELECT product_id FROM mobile_wishlists WHERE user_id=%s', (uid,))]
            if re.fullmatch(r'/wishlist/\d+', path):
                pid = path.split('/')[2]
                if method == 'DELETE':
                    db.execute('DELETE FROM mobile_wishlists WHERE user_id=%s AND product_id=%s', (uid, pid))
                else:
                    require(method == 'POST', 'Method not allowed.', 405)
                    require(any(p['id'] == pid for p in self.catalog(db)), 'Product unavailable.', 404)
                    db.execute('INSERT IGNORE INTO mobile_wishlists(user_id,product_id) VALUES(%s,%s)', (uid, pid))
                return {'message': 'Wishlist updated.'}
            if path == '/notifications':
                require(method in ('GET', 'POST'), 'Method not allowed.', 405)
                if method == 'POST':
                    db.execute('''INSERT IGNORE INTO mobile_notification_reads(user_id,timeline_id)
                        SELECT %s,t.id FROM order_timelines t JOIN orders o ON o.id=t.order_id WHERE o.buyer_id=%s''', (uid, uid))
                return self.notifications(db, uid)
            if re.fullmatch(r'/notifications/\d+', path) and method == 'POST':
                nid = path.split('/')[2]
                row = self.one(db, 'SELECT t.id FROM order_timelines t JOIN orders o ON o.id=t.order_id WHERE t.id=%s AND o.buyer_id=%s', (nid, uid))
                require(row, 'Notification not found.', 404)
                db.execute('INSERT IGNORE INTO mobile_notification_reads(user_id,timeline_id) VALUES(%s,%s)', (uid, nid))
                return {'message': 'Notification read.'}
            if path == '/products' and method == 'GET':
                return self.catalog(db)
            if re.fullmatch(r'/products/\d+', path) and method == 'GET':
                p = next((p for p in self.catalog(db) if p['id'] == path.split('/')[2]), None)
                require(p, 'Product not found.', 404)
                return p
            if path == '/addresses':
                if method == 'GET':
                    return self.addresses(db, uid)
                require(method == 'POST', 'Method not allowed.', 405)
                return self.save_address(db, uid, body)
            if re.fullmatch(r'/addresses/\d+', path):
                aid = path.split('/')[2]
                if method == 'PATCH':
                    return self.save_address(db, uid, body, aid)
                require(method == 'DELETE', 'Method not allowed.', 405)
                self.one(db, 'SELECT id FROM users WHERE id=%s FOR UPDATE', (uid,))
                a = self.one(db, 'SELECT * FROM addresses WHERE id=%s AND user_id=%s FOR UPDATE', (aid, uid))
                require(a, 'Address not found.', 404)
                require(not a['is_default'], 'Choose another default address first.')
                require(not self.one(db, 'SELECT id FROM sellers WHERE pickup_address_id=%s', (aid,)), 'This is a shop pickup address.')
                db.execute('DELETE FROM addresses WHERE id=%s AND user_id=%s', (aid, uid))
                return {'message': 'Address deleted.'}
            if path == '/cart':
                if method == 'GET':
                    return self.cart(db, uid)
                require(method == 'POST', 'Method not allowed.', 405)
                return self.mutate_cart(db, uid, method, body)
            if re.fullmatch(r'/cart/\d+', path) and method in ('PATCH', 'DELETE'):
                return self.mutate_cart(db, uid, method, body, path.split('/')[2])
            if path == '/checkout/quote' and method == 'POST':
                return self.quote(db, uid, body)
            if path == '/checkout' and method == 'POST':
                return self.checkout(db, uid, body)
            if path == '/orders' and method == 'GET':
                return self.orders(db, uid)
            match = re.fullmatch(r'/orders/(\d+)(?:/(\w+))?', path)
            if match:
                oid, action = match.groups()
                if action == 'cancel' and method == 'POST':
                    return self.cancel_order(db, uid, oid, body)
                if action is None and method == 'GET':
                    o = next((o for o in self.orders(db, uid) if o['id'] == oid), None)
                    require(o, 'Order not found.', 404)
                    return o
                raise Problem('This action requires the original review, delivery or settlement workflow.', 503)
            # The exported schema has no tables for these features. Capability flags
            # hide their actions, and writes fail explicitly instead of faking saves.
            if path in ('/wishlist', '/follows', '/vouchers', '/notifications', '/returns') and method == 'GET':
                return []
            raise Problem('This feature is not configured for the connected MySQL schema.', 503)
