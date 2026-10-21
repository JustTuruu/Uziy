import subprocess, pathlib
import uuid
root = pathlib.Path(__file__).resolve().parents[3]
name='uziy_demo_seed_test_' + uuid.uuid4().hex[:10]
def run(args, data=None):
 return subprocess.run(args,input=data,stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True).stdout
def sql(data):
 return run(['docker','exec','-i','uziy-postgres','psql','-v','ON_ERROR_STOP=1','-U','uziy','-d',name],data)
run(['docker','exec','uziy-postgres','createdb','-U','uziy',name])
try:
 schema=run(['docker','exec','uziy-postgres','pg_dump','-U','uziy','-d','uziy','--schema-only','--no-owner'])
 sql(schema)
 sql(b"INSERT INTO users(phone_number,password_hash,role,company_name) VALUES('88112233','unused','COMPANY','Demo'); INSERT INTO platform_settings(id) VALUES(1);")
 seed=(root / 'backend/dev/demo_feed.sql').read_bytes()
 sql(seed);sql(seed)
 sql((root / 'backend/dev/tests/demo_feed_test.sql').read_bytes())
 print('PASS: isolated PostgreSQL seed, repeat-run, 24 campaigns, 120 questions, targeting, pricing, options and video metadata.')
finally:
 run(['docker','exec','uziy-postgres','dropdb','-U','uziy',name])
