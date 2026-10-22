"""Unit checks plus opt-in integration tests in a disposable MySQL schema.

RUN_MYSQL_TESTS=1 uses backend/.env.mysql to CREATE/DROP only a randomly named
lumear_mobile_test_* database. It never imports into the user's existing schema.
"""
import os
import re
import secrets
import unittest
import tempfile
from pathlib import Path
from unittest.mock import patch

try:
    import bcrypt
    import pymysql
    from mysql_store import MySQLStore, settings
    MYSQL_AVAILABLE = True
except ImportError:
    MYSQL_AVAILABLE = False


@unittest.skipUnless(MYSQL_AVAILABLE, 'Install requirements-mysql.txt in backend/.venv')
class MySQLConfigTests(unittest.TestCase):
    def test_environment_overrides_file_without_leaking_password(self):
        with patch.dict(os.environ, {'MYSQL_DATABASE': 'isolated_test', 'MYSQL_PASSWORD': 'a#b=c'}):
            config = settings(Path(__file__).with_name('.does-not-exist'))
        self.assertEqual(config['MYSQL_DATABASE'], 'isolated_test')
        self.assertEqual(config['MYSQL_PASSWORD'], 'a#b=c')

    def test_php_bcrypt_hash_is_supported(self):
        hashed = bcrypt.hashpw(b'TestPassword123', bcrypt.gensalt(rounds=4)).replace(b'$2b$', b'$2y$')
        self.assertTrue(bcrypt.checkpw(b'TestPassword123', hashed))
        self.assertFalse(bcrypt.checkpw(b'wrong-password', hashed))


@unittest.skipUnless(MYSQL_AVAILABLE and os.getenv('RUN_MYSQL_TESTS') == '1',
                     'Set RUN_MYSQL_TESTS=1 to run against a disposable MySQL database')
class MySQLIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config = settings()
        cls.database = 'lumear_mobile_test_' + secrets.token_hex(8)
        cls.admin = pymysql.connect(host=cls.config.get('MYSQL_HOST', '127.0.0.1'),
            port=int(cls.config.get('MYSQL_PORT', 3306)), user=cls.config.get('MYSQL_USER', 'root'),
            password=cls.config.get('MYSQL_PASSWORD', ''), autocommit=True)
        with cls.admin.cursor() as db:
            db.execute('CREATE DATABASE `' + cls.database + '` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci')
        cls.addClassCleanup(cls.cleanup_database)
        upload_parent = Path(__file__).parents[1] / 'build' / 'audit-temp'
        upload_parent.mkdir(parents=True, exist_ok=True)
        cls.upload_temp = tempfile.TemporaryDirectory(dir=upload_parent)
        if not Path(cls.upload_temp.name).resolve().is_relative_to(upload_parent.resolve()):
            raise RuntimeError('Test uploads escaped the build folder')
        cls.addClassCleanup(cls.upload_temp.cleanup)
        cls.store = MySQLStore(dict(cls.config, MYSQL_DATABASE=cls.database, MYSQL_SHIPPING_FEE_MINOR='5000', EMAIL_OTP_SECRET='test-email-secret-strong-enough-123456789', PRIVATE_UPLOAD_ROOT=cls.upload_temp.name))
        schema = Path(__file__).with_name('schema.sql').read_text(encoding='utf-8-sig')
        statements = re.findall(r'CREATE TABLE IF NOT EXISTS `[^`]+` \(.*?\) ENGINE=.*?;', schema, re.S)
        if len(statements) != 30:
            raise RuntimeError('Expected the standalone 30-table mobile schema')
        with cls.store.transaction() as db:
            db.execute('SET FOREIGN_KEY_CHECKS=0')
            for statement in statements:
                db.execute(statement)
            db.execute('SET FOREIGN_KEY_CHECKS=1')
            db.execute("INSERT INTO roles(id,name) VALUES(1,'buyer'),(2,'seller')")
            hashed = bcrypt.hashpw(b'TestPassword123', bcrypt.gensalt(rounds=4)).decode().replace('$2b$', '$2y$')
            for uid, name in [(1, 'Buyer One'), (2, 'Buyer Two'), (3, 'Seller One'), (4, 'Seller Two')]:
                db.execute('INSERT INTO users(id,name,email,password,phone,email_verified_at) VALUES(%s,%s,%s,%s,%s,UTC_TIMESTAMP())',
                    (uid, name, f'user{uid}@example.invalid', hashed, '09171234567'))
                db.execute('INSERT INTO role_user(role_id,user_id) VALUES(%s,%s)', (1 if uid <= 2 else 2, uid))
            db.execute("INSERT INTO categories(id,name,slug) VALUES(1,'Home','home')")
            db.execute("INSERT INTO sellers(id,user_id,name,slug,status) VALUES(1,3,'Shop One','shop-one','approved'),(2,4,'Shop Two','shop-two','approved')")
            db.execute("INSERT INTO products(id,seller_id,category_id,name,slug,description,moderation_status) VALUES(1,1,1,'Basket','basket','A basket','active')")
            db.execute("INSERT INTO product_variants(id,product_id,sku,name,price_minor,stock) VALUES(1,1,'BASKET','Default',10000,5)")
        cls.store.setup_mobile()
        cls.tokens = {}
        for uid in (1, 2, 3, 4):
            cls.tokens[uid] = cls.store.dispatch('POST', '/api/auth/login',
                {'email': f'user{uid}@example.invalid', 'password': 'TestPassword123'})['token']

    @classmethod
    def cleanup_database(cls):
        # This guard prevents a cleanup bug from ever targeting the real schema.
        if not re.fullmatch(r'lumear_mobile_test_[a-f0-9]{16}', cls.database):
            raise RuntimeError('Refusing to drop a non-test schema')
        with cls.admin.cursor() as db:
            db.execute('DROP DATABASE `' + cls.database + '`')
        cls.admin.close()

    def call(self, uid, method, path, body=None):
        return self.store.dispatch(method, '/api' + path, body, self.tokens[uid])

    def test_cloud_copy_preserves_rows_and_private_documents_without_overwriting(self):
        from move_to_cloud import copy_database
        target_name = 'lumear_mobile_test_' + secrets.token_hex(8)
        if not re.fullmatch(r'lumear_mobile_test_[a-f0-9]{16}', target_name):
            raise RuntimeError('Invalid test target')
        with self.admin.cursor() as db: db.execute('CREATE DATABASE `' + target_name + '`')
        target = MySQLStore(dict(self.config, MYSQL_DATABASE=target_name, PRIVATE_UPLOAD_STORAGE='mysql'))
        document = Path(self.upload_temp.name) / 'cloud-copy-test.pdf'
        document.write_bytes(b'%PDF-1.4 private test document')
        try:
            with self.store.transaction() as db:
                db.execute("INSERT INTO seller_kyc_submissions(seller_id,government_id_path,selfie_path,business_permit_path,status) VALUES(2,%s,%s,%s,'pending')", (document.name,)*3)
            counts, documents = copy_database(self.store, target, self.upload_temp.name)
            self.assertGreaterEqual(counts['users'], 4)
            self.assertEqual(documents, 1)
            target.check()
            with target.transaction() as db:
                self.assertEqual(target.one(db,'SELECT content FROM mobile_private_documents WHERE storage_key=%s',(document.name,))['content'],document.read_bytes())
            with self.assertRaisesRegex(ValueError, 'must be empty'):
                copy_database(self.store, target, self.upload_temp.name)
        finally:
            with self.store.transaction() as db: db.execute('DELETE FROM seller_kyc_submissions WHERE seller_id=2')
            with self.admin.cursor() as db: db.execute('DROP DATABASE `' + target_name + '`')


    def test_00_manual_payout_is_owned_bounded_and_idempotent(self):
        from server import Problem
        with self.store.transaction() as db:
            db.execute('INSERT INTO wallet_accounts(seller_id,balance_minor) VALUES(2,10000)')
            db.execute("INSERT INTO seller_payout_accounts(seller_id,type,account_name,account_number_encrypted) VALUES(2,'bank','Seller Two','test-only-account')")
            account_id = str(db.lastrowid)
        body = dict(amount=6000, account_id=account_id, idempotency_key='payout-test-123')
        with self.assertRaises(Problem): self.call(1, 'POST', '/seller/payouts', body)
        with self.assertRaises(Problem): self.call(3, 'POST', '/seller/payouts', body)
        first = self.call(4, 'POST', '/seller/payouts', body)
        self.assertEqual(first, self.call(4, 'POST', '/seller/payouts', body))
        with self.assertRaises(Problem): self.call(4, 'POST', '/seller/payouts', dict(body, amount=7000))
        with self.assertRaises(Problem): self.call(4, 'POST', '/seller/payouts', dict(body, idempotency_key='payout-test-456'))
        report = self.call(4, 'GET', '/seller/workspace')['earnings']
        self.assertEqual(report['wallet_available'], 10000)
        self.assertEqual(report['available_to_request'], 4000)
        self.assertEqual(len(report['payouts']), 1)
        self.assertEqual(report['payouts'][0]['status'], 'requested')
        self.assertNotIn('account_number', report['payout_accounts'][0])
        with self.store.transaction() as db:
            self.assertEqual(self.store.one(db, 'SELECT COUNT(*) n FROM wallet_journals')['n'], 0)

    def test_registration_requires_real_email_proof_and_keeps_buyer_seller_roles(self):
        import base64
        from server import Problem
        sent = {}
        def capture(email, code): sent[email] = code
        def proof(email):
            challenge = self.store.dispatch('POST', '/api/auth/email/send', {'email':email,'purpose':'registration'})
            self.assertNotIn('code',challenge)
            verified = self.store.dispatch('POST', '/api/auth/email/verify', {'challenge_id':challenge['challenge_id'],'code':sent[email]})
            self.assertTrue(verified['verified'])
            return verified['verification_token']
        body = dict(name='New Buyer', email='newbuyer@example.invalid', password='TestPassword123',phone='09171234567',date_of_birth='2000-01-01',account_type='buyer')
        with patch.object(self.store.auth,'send_mail',side_effect=capture):
            with self.assertRaises(Problem): self.store.dispatch('POST','/api/auth/register',body)
            token = proof(body['email'])
            self.store.dispatch('POST','/api/auth/register',dict(body,verification_token=token))
            login = self.store.dispatch('POST','/api/auth/login',dict(email=body['email'],password=body['password']))
            self.assertEqual(login['role'],'buyer')
            self.assertIn('token',login)
            with self.assertRaises(Problem): self.store.dispatch('POST','/api/auth/register',dict(body,email='other@example.invalid',verification_token=token))
            image={'data':base64.b64encode(b'\xff\xd8\xfftest\xff\xd9').decode()}
            pdf={'data':base64.b64encode(b'%PDF-1.4\ntest\n%%EOF').decode()}
            email='newseller@example.invalid'
            with patch.dict(self.store.config, {'PRIVATE_UPLOAD_STORAGE':'mysql'}):
                self.store.dispatch('POST','/api/auth/register',dict(body,email=email,verification_token=proof(email),account_type='seller',shop_name='New Shop',shop_description='My handmade shop',documents={'id':pdf,'selfie':image,'business':pdf}))
            with self.store.transaction() as db:
                db.execute('SELECT content FROM mobile_private_documents')
                self.assertEqual(sorted(row['content'] for row in db.fetchall()),sorted([base64.b64decode(pdf['data']),base64.b64decode(image['data']),base64.b64decode(pdf['data'])]))
            seller=self.store.dispatch('POST','/api/auth/login',dict(email=email,password=body['password']))
            self.assertEqual(seller['role'],'seller')
            self.assertEqual(self.store.dispatch('GET','/api/seller/workspace',token=seller['token'])['shop']['status'],'active')
            # A verified seller can publish immediately without an admin step.
            listing = self.store.dispatch('POST','/api/seller/products',dict(name='Fresh listing',category='Home',description='',price=9900,stock=3,active=True),seller['token'])
            visible = self.call(1,'GET','/products')
            self.assertEqual(next(p for p in visible if p['id']==listing['id'])['price'],9900)
            added = self.call(1,'POST','/cart',dict(product_id=listing['id'],variant_id=next(p for p in visible if p['id']==listing['id'])['variants'][0]['id'],quantity=1))
            hidden = dict(name='Fresh listing',category='Home',description='',price=9900,stock=3,active=False)
            self.store.dispatch('PATCH','/api/seller/products/'+listing['id'],hidden,seller['token'])
            self.assertNotIn(listing['id'],[p['id'] for p in self.call(1,'GET','/products')])
            with self.assertRaises(Problem):
                self.call(1,'POST','/cart',dict(product_id=listing['id'],variant_id=next(p for p in visible if p['id']==listing['id'])['variants'][0]['id'],quantity=1))
            self.call(1,'DELETE','/cart/'+added['id'])
            # Document storage is not represented as an administrator's approval.
            with self.store.transaction() as db:
                self.assertEqual(self.store.one(db,'SELECT status FROM seller_kyc_submissions WHERE seller_id=(SELECT id FROM sellers WHERE user_id=(SELECT id FROM users WHERE email=%s))',(email,))['status'],'pending')
            # Upgrade old pending records without un-hiding products or lifting restrictions.
            with self.store.transaction() as db:
                db.execute("UPDATE sellers SET status='pending' WHERE user_id=(SELECT id FROM users WHERE email=%s)",(email,))
                db.execute("UPDATE products SET moderation_status='pending' WHERE id=%s",(listing['id'],))
                db.execute("UPDATE sellers SET status='suspended' WHERE id=2")
            try:
                sql=Path(__file__).with_name('migrations').joinpath('enable_direct_publishing.sql').read_text()
                sql='\n'.join(line for line in sql.splitlines() if not line.lstrip().startswith('--'))
                with self.store.transaction() as db:
                    for statement in sql.split(';'):
                        if statement.strip(): db.execute(statement)
                    self.assertEqual(self.store.one(db,'SELECT status FROM sellers WHERE id=2')['status'],'suspended')
                migrated=self.store.dispatch('GET','/api/seller/workspace',token=seller['token'])
                self.assertEqual(migrated['shop']['status'],'active')
                self.assertEqual(migrated['products'][0]['moderation'],'active')
                self.assertNotIn(listing['id'],[p['id'] for p in self.call(1,'GET','/products')])
                with self.assertRaises(Problem):
                    self.call(4,'POST','/seller/products',dict(name='Blocked',category='Home',price=1000,stock=1))
            finally:
                with self.store.transaction() as db: db.execute("UPDATE sellers SET status='approved' WHERE id=2")
            # Failed SMTP delivery rolls back its code and never verifies an account.
            with patch.object(self.store.auth,'send_mail',side_effect=Problem('Delivery failed',503)):
                with self.assertRaises(Problem): proof('failed@example.invalid')
            with self.store.transaction() as db:
                self.assertIsNone(self.store.one(db,'SELECT id FROM email_otp_codes WHERE email=%s',('failed@example.invalid',)))

    def test_otp_expiry_attempt_limits_cooldown_and_existing_account(self):
        from server import Problem
        sent={}
        with patch.object(self.store.auth,'send_mail',side_effect=lambda email,code:sent.update({email:code})):
            send=dict(email='limits@example.invalid',purpose='registration')
            challenge=self.store.dispatch('POST','/api/auth/email/send',send)['challenge_id']
            with self.assertRaises(Problem):self.store.dispatch('POST','/api/auth/email/send',send)
            wrong='000000' if sent[send['email']]!='000000' else '999999'
            for _ in range(5):self.assertFalse(self.store.dispatch('POST','/api/auth/email/verify',dict(challenge_id=challenge,code=wrong))['verified'])
            self.assertFalse(self.store.dispatch('POST','/api/auth/email/verify',dict(challenge_id=challenge,code=sent[send['email']]))['verified'])
            with self.store.transaction() as db:
                db.execute('UPDATE email_otp_codes SET created_at=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 2 MINUTE) WHERE id=%s',(challenge,))
            challenge=self.store.dispatch('POST','/api/auth/email/send',send)['challenge_id']
            with self.store.transaction() as db:db.execute('UPDATE email_otp_codes SET expires_at=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 SECOND) WHERE id=%s',(challenge,))
            self.assertFalse(self.store.dispatch('POST','/api/auth/email/verify',dict(challenge_id=challenge,code=sent[send['email']]))['verified'])
            with self.store.transaction() as db:db.execute('UPDATE users SET email_verified_at=NULL WHERE id=2')
            credentials=dict(email='user2@example.invalid',password='TestPassword123')
            self.assertTrue(self.store.dispatch('POST','/api/auth/login',credentials)['requires_email_verification'])
            r=self.store.dispatch('POST','/api/auth/email/send',dict(credentials,purpose='account'))
            self.assertTrue(self.store.dispatch('POST','/api/auth/email/verify',dict(challenge_id=r['challenge_id'],code=sent[credentials['email']]))['verified'])
            self.assertIn('token',self.store.dispatch('POST','/api/auth/login',credentials))

    def test_shared_checkout_seller_ownership_earnings_and_exactly_once_cancel(self):
        from server import Problem
        address = self.call(1, 'POST', '/addresses', dict(label='Home', name='Buyer One',
            phone='09171234567', street='Main street', barangay='Central', city='Manila',
            province='Metro Manila', postal_code='1000'))
        with self.assertRaises(Problem):
            self.call(2, 'PATCH', '/addresses/' + address['id'], {'city': 'Other'})
        self.assertEqual(self.call(2, 'GET', '/addresses'), [])
        self.call(1, 'POST', '/cart', dict(product_id='1', variant_id='1', quantity=2))
        self.assertEqual(self.call(2, 'GET', '/cart'), [])
        quote = self.call(1, 'POST', '/checkout/quote', dict(address_id=address['id'], vouchers=[]))
        self.assertEqual(quote['total'], 25000)
        body = dict(address_id=address['id'], vouchers=[], payment_method='COD', note='',
                    expected_quote=quote, idempotency_key='checkout-test-123')
        bad = dict(body, expected_quote=dict(quote, total=1))
        with self.assertRaises(Problem):
            self.call(1, 'POST', '/checkout', bad)
        self.assertEqual(len(self.call(1, 'GET', '/cart')), 1)
        result = self.call(1, 'POST', '/checkout', body)
        self.assertEqual(self.call(1, 'POST', '/checkout', body), result)
        order = result['orders'][0]
        self.assertEqual(self.call(1, 'GET', '/products')[0]['stock'], 3)
        self.assertEqual(self.call(2, 'GET', '/orders'), [])
        self.assertEqual(len(self.call(3, 'GET', '/seller/workspace')['orders']), 1)
        self.assertEqual(self.call(4, 'GET', '/seller/workspace')['orders'], [])
        for uid, path in [(2, '/orders/' + order['id'] + '/cancel'), (4, '/seller/orders/' + order['id'] + '/cancel')]:
            with self.assertRaises(Problem):
                self.call(uid, 'POST', path, {'reason': 'Wrong owner'})
        self.call(1, 'POST', '/orders/' + order['id'] + '/cancel', {'reason': 'Changed my mind'})
        self.call(1, 'POST', '/orders/' + order['id'] + '/cancel', {'reason': 'Retry'})
        self.assertEqual(self.call(1, 'GET', '/products')[0]['stock'], 5)
        earnings = self.call(3, 'GET', '/seller/workspace')['earnings']
        self.assertEqual(earnings['gross_sales'], 0)
        self.assertIsNone(earnings['wallet_available'])
        # Ledger balances and payouts are independent of order-sum estimates.
        with self.store.transaction() as db:
            db.execute('INSERT INTO wallet_accounts(seller_id,balance_minor) VALUES(1,12345)')
        earnings = self.call(3, 'GET', '/seller/workspace')['earnings']
        self.assertEqual(earnings['wallet_available'], 12345)
        self.assertIsNone(earnings['wallet_pending'])
        self.assertEqual(earnings['net_sales'], 0)
        with self.assertRaises(Problem):
            self.call(1, 'GET', '/seller/workspace')
        # Direct publishing makes a saved active listing visible to buyers.
        listing = self.call(3, 'POST', '/seller/products', dict(name='New Basket', category='Home',
            description='New listing', price=12000, stock=4, active=True))
        self.assertIn(listing['id'], [p['id'] for p in self.call(1, 'GET', '/products')])
        mine = self.call(3, 'GET', '/seller/workspace')['products']
        self.assertEqual(next(p for p in mine if p['id'] == listing['id'])['moderation'], 'active')
        edit = dict(name='New Basket', category='Home', description='Updated', price=13000, stock=6, active=True)
        with self.assertRaises(Problem):
            self.call(4, 'PATCH', '/seller/products/' + listing['id'], edit)
        self.call(3, 'PATCH', '/seller/products/' + listing['id'], edit)
        self.assertEqual(next(p for p in self.call(3, 'GET', '/seller/workspace')['products'] if p['id'] == listing['id'])['stock'], 6)
        # A second order can be prepared but cannot be cancelled after packing.
        self.call(1, 'POST', '/cart', dict(product_id='1', variant_id='1', quantity=1))
        quote2 = self.call(1, 'POST', '/checkout/quote', dict(address_id=address['id'], vouchers=[]))
        order2 = self.call(1, 'POST', '/checkout', dict(body, expected_quote=quote2, idempotency_key='checkout-test-456'))['orders'][0]
        self.call(3, 'POST', '/seller/orders/' + order2['id'] + '/prepare', {})
        with self.assertRaises(Problem):
            self.call(1, 'POST', '/orders/' + order2['id'] + '/cancel', {'reason': 'Too late'})
        self.assertEqual(next(p for p in self.call(1, 'GET', '/products') if p['id']=='1')['stock'], 4)
        with self.store.transaction() as db:
            db.execute("INSERT INTO two_factor_credentials(user_id,secret,confirmed_at) VALUES(2,'test-only-placeholder',UTC_TIMESTAMP())")
        with self.assertRaises(Problem):
            self.store.dispatch('POST', '/api/auth/login', dict(email='user2@example.invalid', password='TestPassword123'))
        with self.assertRaises(Problem):
            self.call(2, 'GET', '/me')
        # Existing mobile tokens also expire when the web changes the password.
        with self.store.transaction() as db:
            db.execute('UPDATE users SET password=%s WHERE id=4', (bcrypt.hashpw(b'ChangedPassword123', bcrypt.gensalt(rounds=4)).decode(),))
        with self.assertRaises(Problem):
            self.call(4, 'GET', '/seller/workspace')


if __name__ == '__main__':
    unittest.main()
