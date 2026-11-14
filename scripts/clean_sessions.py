import os
import shutil
import sqlite3
import json
import sys

# Support checking both RDP and runneradmin profiles
db_candidates = [
    os.path.expandvars(r'%USERPROFILE%\.local\share\opencode\opencode.db'),
    r'C:\Users\RDP\.local\share\opencode\opencode.db',
    r'C:\Users\runneradmin\.local\share\opencode\opencode.db'
]

def clean_db(db_path):
    if not os.path.exists(db_path):
        return 0

    try:
        shutil.copyfile(db_path, db_path + '.bak')
    except Exception:
        pass

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='session_v2';")
    if not cur.fetchone():
        conn.close()
        return 0

    cur.execute('SELECT id FROM session_v2;')
    sessions = [r[0] for r in cur.fetchall()]

    cleaned = 0
    for sid in sessions:
        try:
            # 1. Delete compaction, rate limit errors and failed assistant responses
            cur.execute(
                'DELETE FROM session_message WHERE session_id=? AND '
                '(type="compaction" OR data LIKE "%finish%error%" OR data LIKE "%provider.free-limit%" OR data LIKE "%FreeUsageLimit%" OR data LIKE "%rate_limit%" OR data LIKE "%rate limit%");',
                [sid]
            )

            # 2. Truncate heavy tool outputs in past messages to avoid huge context payloads
            cur.execute('SELECT max(seq) FROM session_message WHERE session_id=?;', [sid])
            row = cur.fetchone()
            max_seq = row[0] if row and row[0] else 0
            safe_seq = max(0, max_seq - 15)

            cur.execute(
                'SELECT id, seq, data FROM session_message WHERE session_id=? AND type="assistant" AND seq < ?;',
                [sid, safe_seq]
            )
            for msg_id, _seq, raw in cur.fetchall():
                try:
                    data = json.loads(raw)
                    changed = False
                    if isinstance(data.get('content'), list):
                        new_content = []
                        for item in data['content']:
                            itype = item.get('type')
                            if itype == 'reasoning':
                                changed = True
                                continue
                            if itype == 'tool' and isinstance(item.get('state'), dict) and isinstance(item['state'].get('content'), list):
                                for c in item['state']['content']:
                                    if isinstance(c, dict) and 'text' in c and len(str(c['text'])) > 250:
                                        c['text'] = str(c['text'])[:250] + '\n... [Truncated for context]'
                                        changed = True
                            new_content.append(item)
                        data['content'] = new_content
                    if changed:
                        cur.execute('UPDATE session_message SET data=? WHERE id=?;',
                                    [json.dumps(data, ensure_ascii=False), msg_id])
                        cleaned += 1
                except Exception:
                    pass

            # 3. RESET TOKEN COUNTERS COMPLETELY TO ZERO
            cur.execute(
                'UPDATE session_v2 SET tokens_input = 0, tokens_output = 0, tokens_reasoning = 0, '
                'tokens_cache_read = 0, tokens_cache_write = 0, cost = 0, '
                'model = replace(model, \'"variant":"max"\', \'"variant":"default"\') WHERE id = ?;',
                [sid]
            )
        except Exception:
            pass

    conn.commit()
    conn.close()
    return cleaned

def main():
    total_cleaned = 0
    found = False
    for db_path in db_candidates:
        if os.path.exists(db_path):
            found = True
            total_cleaned += clean_db(db_path)
    if not found:
        print('DB_NOT_FOUND')
    else:
        print('CLEANED_OK:' + str(total_cleaned))

if __name__ == '__main__':
    main()
