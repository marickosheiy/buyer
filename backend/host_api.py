"""Serve the existing MySQL API behind a hosting provider's HTTPS endpoint."""
import json
import os
from http import HTTPStatus

from mysql_store import MySQLStore
from server import Problem, require

MAX_BODY = 36 * 1024 * 1024


def create_application(store):
    def application(environ, start_response):
        try:
            length = int(environ.get('CONTENT_LENGTH') or 0)
            require(0 <= length <= MAX_BODY, 'Request is too large.', 413)
            body = json.loads(environ['wsgi.input'].read(length)) if length else {}
            path = environ.get('PATH_INFO', '/')
            if environ.get('QUERY_STRING'):
                path += '?' + environ['QUERY_STRING']
            result = store.dispatch(environ['REQUEST_METHOD'], path, body,
                environ.get('HTTP_AUTHORIZATION', '').removeprefix('Bearer '))
            status = 200
        except Problem as error:
            status, result = error.status, {'message': error.message}
        except (json.JSONDecodeError, UnicodeDecodeError, ValueError, TypeError):
            status, result = 400, {'message': 'Invalid request. Check your fields and try again.'}
        except Exception:
            status, result = 500, {'message': 'The server could not complete the request. Please try again.'}
        raw = json.dumps(result).encode()
        start_response(f'{status} {HTTPStatus(status).phrase}', [
            ('Content-Type', 'application/json; charset=utf-8'),
            ('Content-Length', str(len(raw))), ('Cache-Control', 'no-store'),
            ('X-Content-Type-Options', 'nosniff'),
        ])
        return [raw]
    return application


if __name__ == '__main__':
    from waitress import serve
    store = MySQLStore()
    try:
        store.check()
    except Exception:
        raise SystemExit('Hosted MySQL is not ready. Check the private connection settings and import the Lumear database.')
    # One process preserves the existing in-memory session and rate-limit rules.
    serve(create_application(store), host=os.environ.get('HOST', '0.0.0.0'), port=int(os.environ.get('PORT', '8000')),
          threads=4, max_request_body_size=MAX_BODY, max_request_header_size=16384,
          channel_timeout=60, expose_tracebacks=False, ident='Lumear')
