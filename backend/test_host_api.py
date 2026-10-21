import io
import json
import unittest
from unittest.mock import Mock

from host_api import MAX_BODY, create_application
from server import Problem


class HostedAPITests(unittest.TestCase):
    def request(self, store, body=b'', length=None):
        status = []
        result = create_application(store)({
            'REQUEST_METHOD': 'POST', 'PATH_INFO': '/api/auth/login',
            'QUERY_STRING': '', 'CONTENT_LENGTH': str(len(body) if length is None else length),
            'HTTP_AUTHORIZATION': 'Bearer private-test-token', 'wsgi.input': io.BytesIO(body),
        }, lambda code, headers: status.append(code))
        return status[0], json.loads(b''.join(result))

    def test_existing_api_auth_and_validation_are_preserved(self):
        store = Mock()
        store.dispatch.return_value = {'role': 'buyer'}
        self.assertEqual(self.request(store, b'{"email":"buyer@example.invalid"}'),
                         ('200 OK', {'role': 'buyer'}))
        store.dispatch.assert_called_once_with('POST', '/api/auth/login',
            {'email': 'buyer@example.invalid'}, 'private-test-token')
        store.dispatch.side_effect = Problem('Sign in required.', 401)
        self.assertEqual(self.request(store)[0], '401 Unauthorized')

    def test_bad_or_oversized_requests_do_not_reach_database(self):
        store = Mock()
        self.assertEqual(self.request(store, b'not json')[0], '400 Bad Request')
        self.assertEqual(self.request(store, length=MAX_BODY+1)[0], '413 Request Entity Too Large')
        store.dispatch.assert_not_called()

    def test_unexpected_errors_do_not_expose_private_details(self):
        store = Mock()
        store.dispatch.side_effect = RuntimeError('private database credentials')
        status, body = self.request(store)
        self.assertEqual(status, '500 Internal Server Error')
        self.assertNotIn('private', body['message'])
