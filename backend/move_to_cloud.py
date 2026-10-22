"""Copy the standalone local database into a NEW, EMPTY hosted database."""
from pathlib import Path

from mysql_store import MySQLStore, settings


def copy_database(source, destination, upload_root):
    source_identity = tuple(source.config.get(k) for k in ('MYSQL_HOST', 'MYSQL_PORT', 'MYSQL_DATABASE'))
    target_identity = tuple(destination.config.get(k) for k in ('MYSQL_HOST', 'MYSQL_PORT', 'MYSQL_DATABASE'))
    if source_identity == target_identity:
        raise ValueError('Source and destination must be different databases.')
    upload_root = Path(upload_root).resolve()
    with source.transaction() as src, destination.transaction() as dst:
        dst.execute('SHOW TABLES')
        if dst.fetchall():
            raise ValueError('The hosted database must be empty. Existing tables will never be overwritten.')
        src.execute('SHOW TABLES')
        tables = [next(iter(row.values())) for row in src.fetchall()]
        definitions = {}
        documents = {}
        # Check document availability before making any remote schema changes.
        src.execute('SELECT government_id_path,selfie_path,business_permit_path FROM seller_kyc_submissions')
        for row in src.fetchall():
            for key in row.values():
                if not key:
                    continue
                if 'mobile_private_documents' in tables:
                    src.execute('SELECT storage_key FROM mobile_private_documents WHERE storage_key=%s', (key,))
                    if src.fetchone():
                        continue
                relative = key.replace('\\', '/')
                path = (upload_root / relative).resolve()
                if not path.is_relative_to(upload_root) or not path.is_file():
                    raise ValueError('A referenced seller document is missing or outside private storage. Migration stopped.')
                documents[key] = path.read_bytes()
        for table in tables:
            escaped = table.replace('`', '``')
            src.execute(f'SHOW CREATE TABLE `{escaped}`')
            definitions[table] = src.fetchone()['Create Table']
        dst.execute('SET FOREIGN_KEY_CHECKS=0')
        counts = {}
        for table, definition in definitions.items():
            dst.execute(definition)
        dst.execute('''CREATE TABLE IF NOT EXISTS mobile_private_documents (
            storage_key VARCHAR(255) NOT NULL PRIMARY KEY,content MEDIUMBLOB NOT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci''')
        for table in tables:
            escaped = table.replace('`', '``')
            src.execute(f'SELECT * FROM `{escaped}`')
            rows = src.fetchall()
            if rows:
                columns = ','.join('`'+key.replace('`','``')+'`' for key in rows[0])
                placeholders = ','.join(['%s']*len(rows[0]))
                dst.executemany(f'INSERT INTO `{escaped}` ({columns}) VALUES({placeholders})',
                                [tuple(row.values()) for row in rows])
            dst.execute(f'SELECT COUNT(*) n FROM `{escaped}`')
            if dst.fetchone()['n'] != len(rows):
                raise ValueError('Row count verification failed. Migration stopped.')
            counts[table] = len(rows)
        # Files must survive a restart on the free, stateless API host.
        for key, content in documents.items():
            dst.execute('INSERT INTO mobile_private_documents(storage_key,content) VALUES(%s,%s)', (key, content))
        dst.execute('SET FOREIGN_KEY_CHECKS=1')
        return counts, len(documents)


if __name__ == '__main__':
    root = Path(__file__).parent
    try:
        local = MySQLStore(settings(root / '.env.mysql'))
        cloud = MySQLStore(settings(root / '.env.cloud'))
        if not cloud.config.get('MYSQL_SSL_REQUIRED'):
            raise ValueError('Hosted MySQL must use verified TLS.')
        counts, documents = copy_database(local, cloud,
            local.config.get('PRIVATE_UPLOAD_ROOT', str(root / 'private_uploads')))
        print(f'Copied {len(counts)} tables and {sum(counts.values())} rows; verified row counts.')
        print(f'Preserved {documents} private seller documents in hosted storage.')
        cloud.check()
        print('Hosted database check passed. Local data was kept.')
    except Exception as error:
        # DB driver errors can include host/user details; never print credentials.
        print(str(error) if isinstance(error, ValueError) else 'Cloud migration failed. Check the private connection and CA certificate.')
        raise SystemExit(1)
