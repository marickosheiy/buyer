import tempfile
import time
import unittest
import base64
from pathlib import Path

from server import Problem, Store


class BuyerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.store = Store(Path(self.temp.name) / 'buyer.sqlite3')
        self.token = self.store.dispatch('POST', '/api/auth/login', {
            'email': 'juanmiguel.delacruz@example.com', 'password': 'Mamimili@2026'})['token']
        self.token2 = self.store.dispatch('POST', '/api/auth/login', {
            'email': 'anamarie.reyes@example.com', 'password': 'Suki#2026Ana'})['token']

    def call(self, method, path, body=None, token=None):
        return self.store.dispatch(method, '/api' + path, body, self.token if token is None else token)

    def add(self, product='P-02', variant='', qty=1):
        return self.call('POST', '/cart', {'product_id': product, 'variant_id': variant, 'quantity': qty})

    def checkout_body(self, codes=None):
        body = {'address_id': 'ADDR-1', 'vouchers': codes or []}
        return dict(body, expected_quote=self.call('POST', '/checkout/quote', body),
                    payment_method='COD', note='', idempotency_key='test-checkout-1')

    def test_login_and_owner_boundaries(self):
        with self.assertRaises(Problem) as error:
            self.call('GET', '/addresses/ADDR-3')
        self.assertEqual(error.exception.status, 404)
        with self.assertRaises(Problem):
            self.call('POST', '/auth/login', {'email': 'juanmiguel.delacruz@example.com', 'password': 'wrong'})
        with self.assertRaises(Problem):
            self.call('GET', '/orders', token='invalid')

    def test_profile_validation_and_password_change(self):
        for name in ['', 'J', 'Juan123']:
            with self.assertRaises(Problem):
                self.call('PATCH', '/me', {'name': name})
        self.call('PATCH', '/me', {'name': 'Juan Miguel Jr.'})
        self.assertEqual(self.call('GET', '/me')['name'], 'Juan Miguel Jr.')
        for password in ['Mami@26', 'mamimili@2027', 'MAMIMILI@2027', 'Mamimili@abcd', 'Mamimili2027', 'Mamimili@2026']:
            with self.assertRaises(Problem):
                self.call('POST', '/auth/password', {'current_password': 'Mamimili@2026',
                    'new_password': password, 'confirm_password': password})
        self.call('POST', '/auth/password', {'current_password': 'Mamimili@2026',
            'new_password': 'Mamimili@2027', 'confirm_password': 'Mamimili@2027'})
        with self.assertRaises(Problem):
            self.call('POST', '/auth/login', {'email': 'juanmiguel.delacruz@example.com', 'password': 'Mamimili@2026'})
        self.assertIn('token', self.call('POST', '/auth/login', {
            'email': 'juanmiguel.delacruz@example.com', 'password': 'Mamimili@2027'}))

    def test_worked_checkout_and_duplicate_request(self):
        self.add('P-01', 'Natural-M')
        self.add('P-02')
        self.add('P-05')
        for code in ['MCH50', 'PLAT100', 'FREESHIP']:
            self.call('POST', f'/vouchers/{code}/claim')
        body = self.checkout_body(['MCH50', 'PLAT100', 'FREESHIP'])
        quote = body['expected_quote']
        self.assertEqual((quote['subtotal'], quote['shipping'], quote['total']), (109800, 18500, 108300))
        first = self.call('POST', '/checkout', body)
        self.assertEqual(self.call('POST', '/checkout', body), first)
        self.assertEqual(len(first['orders']), 2)
        self.assertEqual(sum(o['total'] for o in first['orders']), 108300)
        self.assertEqual(len(self.call('GET', '/orders')), 2)
        self.assertEqual(self.call('GET', '/cart'), [])
        self.assertEqual(self.call('GET', '/products/P-02')['stock'], 19)
        # Restart the Store object: records are persisted in SQLite.
        self.store = Store(self.store.path)
        self.assertEqual(len(self.call('GET', '/orders')), 2)

    def test_price_change_blocks_order_and_tampered_total(self):
        self.add()
        body = self.checkout_body()
        with self.store.transaction() as db:
            p = self.store.get(db, 'product', 'P-02')
            p['variants'][0]['price'] = 48000
            self.store.put(db, 'product', p)
        with self.assertRaises(Problem) as error:
            self.call('POST', '/checkout', body)
        self.assertEqual(error.exception.status, 409)
        self.assertEqual(self.call('GET', '/orders'), [])
        body = self.checkout_body()
        body['expected_quote']['total'] = 100
        with self.assertRaises(Problem):
            self.call('POST', '/checkout', body)

    def test_cart_variants_stock_and_limits(self):
        with self.assertRaises(Problem):
            self.add('P-01', 'Black-M')
        with self.assertRaises(Problem):
            self.add('P-01')
        self.add('P-01', 'Natural-S')
        self.add('P-01', 'Natural-S')
        self.add('P-01', 'Natural-M')
        items = self.call('GET', '/cart')
        self.assertEqual(len(items), 2)
        self.assertEqual(items[0]['quantity'], 2)
        for qty in [0, -1, 1.5, True, 999999]:
            with self.assertRaises(Problem):
                self.call('PATCH', '/cart/' + items[0]['id'], {'quantity': qty})
        with self.assertRaises(Problem):
            self.add('P-07', qty=3)

    def test_two_buyers_keep_separate_cart_wallet_and_wishlist(self):
        self.add('P-02', qty=2)
        self.call('POST', '/cart', {'product_id': 'P-02', 'quantity': 1}, token=self.token2)
        for token in (self.token, self.token2):
            self.call('POST', '/vouchers/MCH50/claim', token=token)
            self.call('POST', '/wishlist/P-02', token=token)
        self.assertEqual(self.call('GET', '/cart')[0]['quantity'], 2)
        self.assertEqual(self.call('GET', '/cart', token=self.token2)[0]['quantity'], 1)
        for token in (self.token, self.token2):
            self.assertEqual(len(self.call('GET', '/wishlist', token=token)), 1)
            self.assertTrue(next(v for v in self.call('GET', '/vouchers', token=token) if v['id'] == 'MCH50')['claimed'])

    def test_concurrent_buyers_cannot_oversell(self):
        self.add('P-03')
        first_body = self.checkout_body()
        self.call('POST', '/cart', {'product_id': 'P-03', 'quantity': 1}, token=self.token2)
        body = {'address_id': 'ADDR-3', 'vouchers': []}
        body.update(expected_quote=self.call('POST', '/checkout/quote', body, token=self.token2),
                    payment_method='COD', idempotency_key='other-buyer-1')
        self.call('POST', '/checkout', body, token=self.token2)
        with self.assertRaises(Problem):
            self.call('POST', '/checkout', first_body)
        self.assertEqual(self.call('GET', '/products/P-03')['stock'], 0)

    def test_cancellation_restores_once_and_returns_voucher(self):
        self.add(qty=2)
        self.call('POST', '/vouchers/MCH50/claim')
        result = self.call('POST', '/checkout', self.checkout_body(['MCH50']))
        id = result['orders'][0]['id']
        with self.assertRaises(Problem):
            self.call('POST', f'/orders/{id}/cancel', {'reason': ''})
        for _ in range(2):
            self.call('POST', f'/orders/{id}/cancel', {'reason': 'Changed my mind'})
        self.assertEqual(self.call('GET', '/products/P-02')['stock'], 20)
        self.assertFalse(next(v for v in self.call('GET', '/vouchers') if v['id'] == 'MCH50')['redeemed'])
        with self.assertRaises(Problem):
            self.call('GET', f'/orders/{id}', token=self.token2)

    def test_voucher_boundaries_caps_and_expiry(self):
        self.add()
        self.call('POST', '/vouchers/MCH50/claim')
        self.call('POST', '/vouchers/MCH10/claim')
        for price, allowed in [(29999, False), (30000, True), (30001, True)]:
            with self.store.transaction() as db:
                p = self.store.get(db, 'product', 'P-02')
                p['variants'][0]['price'] = price
                self.store.put(db, 'product', p)
            body = {'address_id': 'ADDR-1', 'vouchers': ['MCH50']}
            if allowed:
                self.assertEqual(self.call('POST', '/checkout/quote', body)['discounts'][0]['amount'], 5000)
            else:
                with self.assertRaises(Problem):
                    self.call('POST', '/checkout/quote', body)
        for code in ['MCHOLD', 'MCHSOON', 'MCHMAX', 'NOSUCHCODE']:
            with self.assertRaises(Problem):
                self.call('POST', f'/vouchers/{code}/claim')
        with self.store.transaction() as db:
            p = self.store.get(db, 'product', 'P-02')
            p['variants'][0]['price'] = 125000
            self.store.put(db, 'product', p)
        q = self.call('POST', '/checkout/quote', {'address_id': 'ADDR-1', 'vouchers': ['MCH10']})
        self.assertEqual(q['discounts'][0]['amount'], 10000)
        with self.assertRaises(Problem):
            self.call('POST', '/checkout/quote', {'address_id': 'ADDR-1', 'vouchers': ['MCH10', 'MCH50']})

    def test_address_limit_default_and_order_snapshot(self):
        with self.assertRaises(Problem):
            self.call('DELETE', '/addresses/ADDR-1')
        a = self.call('GET', '/addresses/ADDR-1')
        self.add()
        o = self.call('POST', '/checkout', self.checkout_body())['orders'][0]
        self.call('PATCH', '/addresses/ADDR-1', dict(a, street='Changed street'))
        self.assertNotEqual(self.call('GET', f"/orders/{o['id']}")['address']['street'], 'Changed street')
        for i in range(7):
            self.call('POST', '/addresses', dict(a, label=f'Address {i}', default=False))
        with self.assertRaises(Problem):
            self.call('POST', '/addresses', dict(a, default=False))
        with self.assertRaises(Problem):
            self.call('POST', '/checkout/quote', {'address_id': 'ADDR-4'})

    def test_receipt_reviews_and_notification_read(self):
        self.add()
        o = self.call('POST', '/checkout', self.checkout_body())['orders'][0]
        id = o['id']
        with self.assertRaises(Problem):
            self.call('POST', f'/orders/{id}/receive')
        with self.store.transaction() as db:
            o.update(status='To Receive', delivered_at=time.time())
            self.store.put(db, 'order', o, 'buyer1')
        self.call('POST', f'/orders/{id}/receive')
        review = {'product_id': 'P-02', 'stars': 5, 'text': 'Matibay at maganda!'}
        self.call('POST', f'/orders/{id}/review', review)
        self.call('POST', f'/orders/{id}/review', dict(review, stars=3))
        with self.assertRaises(Problem):
            self.call('POST', f'/orders/{id}/review', review)
        p = next(p for p in self.call('GET', '/products') if p['id'] == 'P-02')
        self.assertEqual((p['review_count'], p['rating']), (1, 3))
        self.call('POST', '/notifications')
        self.assertTrue(all(n['read'] for n in self.call('GET', '/notifications')))

    def test_chat_limits_and_idempotency(self):
        body = {'text': 'Hi, available pa po ba?', 'idempotency_key': 'message-key-123'}
        self.call('POST', '/chat/s1', body)
        self.call('POST', '/chat/s1', body)
        self.assertEqual(len(self.call('GET', '/chat/s1')), 1)
        with self.assertRaises(Problem):
            self.call('POST', '/chat/s1', dict(body, text='x' * 1001, idempotency_key='message-key-456'))
        self.assertEqual(self.call('GET', '/chat/s1', token=self.token2), [])

    def test_return_delivery_window_evidence_and_duplicate(self):
        self.add()
        o = self.call('POST', '/checkout', self.checkout_body())['orders'][0]
        id = o['id']
        png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jG1kAAAAASUVORK5CYII='
        body = {'reason': 'Damaged item', 'description': 'Basket arrived with a broken rim.',
                'photos': [{'name': 'review.png', 'data': png}]}
        with self.assertRaises(Problem):
            self.call('POST', f'/orders/{id}/return', body)
        with self.store.transaction() as db:
            o.update(status='To Receive', delivered_at=time.time() - 86400)
            self.store.put(db, 'order', o, 'buyer1')
        for photos in [[], body['photos'] * 6, [{'name': 'renamed_exe.jpg', 'data': base64.b64encode(b'MZexe').decode()}]]:
            with self.assertRaises(Problem):
                self.call('POST', f'/orders/{id}/return', dict(body, photos=photos))
        first = self.call('POST', f'/orders/{id}/return', body)
        self.assertEqual(first, self.call('POST', f'/orders/{id}/return', body))
        self.assertEqual(self.call('GET', f'/orders/{id}')['status'], 'Return/Refund')


if __name__ == '__main__':
    unittest.main()
