import os
import shutil
import sqlite3
import json
import sys

DB = os.path.expandvars(r'%USERPROFILE%\.local\share\opencode\opencode.db')


def main():
    if not os.path.exists(DB):
        print('DB_NOT_FOUND')
        return

    try:
        shutil.copyfile(DB, DB + '.bak')
    except Exception:
        pass

    conn = sqlite3.connect(DB)
    cur = conn.cursor()

    cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='session_v2';")
    if not cur.fetchone():
        print('SCHEMA_UNSUPPORTED')
        conn.close()
        return

    cur.execute('SELECT id FROM session_v2;')
    sessions = [r[0] for r in cur.fetchall()]

    cleaned = 0
    for sid in sessions:
        try:
            cur.execute(
                'DELETE FROM session_message WHERE session_id=? AND '
                '(type="compaction" OR (type="assistant" AND data LIKE "%\\"finish\\": \\"error\\"%"));',
                [sid]
            )

            cur.execute('SELECT max(seq) FROM session_message WHERE session_id=?;', [sid])
            row = cur.fetchone()
            max_seq = row[0] if row and row[0] else 0
            safe_seq = max(0, max_seq - 20)

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
                            if itype == 'tool' and isinstance(item.get('state'), dict) \
                                    and isinstance(item['state'].get('content'), list):
                                for c in item['state']['content']:
                                    if isinstance(c, dict) and 'text' in c and len(str(c['text'])) > 350:
                                        c['text'] = str(c['text'])[:350] + '\n... [Truncated for context]'
                                        changed = True
                            new_content.append(item)
                        data['content'] = new_content
                    if changed:
                        cur.execute('UPDATE session_message SET data=? WHERE id=?;',
                                    [json.dumps(data, ensure_ascii=False), msg_id])
                        cleaned += 1
                except Exception:
                    pass

            cur.execute(
                'UPDATE session_v2 SET tokens_input = CASE WHEN tokens_input > 15000 THEN 15000 ELSE tokens_input END, '
                'model = replace(model, \'"variant":"max"\', \'"variant":"default"\') WHERE id = ?;',
                [sid]
            )
        except Exception:
            pass

    conn.commit()
    conn.close()
    print('CLEANED_OK:' + str(cleaned))


if __name__ == '__main__':
    main()
