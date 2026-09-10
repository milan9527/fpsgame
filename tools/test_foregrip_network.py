"""Two actual ENet clients exercise attachment inventory and remote visuals."""
import os
from pathlib import Path
import subprocess
import time
from test_accounts import account
ROOT = Path(__file__).resolve().parents[1]
identities = [account('network-0'), account('network-1')]
env = dict(os.environ, GAME_PORT='27028', API_URL='http://127.0.0.1:8000', XDG_DATA_HOME=str(ROOT/'artifacts/grip-server-data'))
env['SERVER_SECRET'] = next(line.split('=',1)[1] for line in (ROOT/'.env').read_text().splitlines() if line.startswith('SERVER_SECRET='))
server_path = ROOT/'artifacts/foregrip-network-server.log'
clients = []
with server_path.open('w') as output:
    server = subprocess.Popen([str(ROOT/'tools/godot'),'--headless','--path','client','--script','../tests/foregrip_network_server.gd','--','--server'],cwd=ROOT,env=env,stdout=output,stderr=subprocess.STDOUT)
    try:
        for _ in range(250):
            if 'SERVER_READY' in server_path.read_text():break
            assert server.poll() is None, 'Fixture server exited'
            time.sleep(.1)
        else:raise AssertionError('Fixture readiness timeout')
        for i, identity in enumerate(identities):
            path = ROOT/('artifacts/foregrip-network-client-%d.log'%i)
            log = path.open('w')
            variables = dict(os.environ, TEST_USERNAME=identity['username'], TEST_PASSWORD=identity['password'],
                             TEST_GAME_PORT='27028', API_URL='http://127.0.0.1:8000', GRIP_OBSERVER=str(i))
            proc = subprocess.Popen([str(ROOT/'tools/godot'),'--headless','--path','client','--script','../tests/foregrip_network_client.gd','--','--bot-client'],cwd=ROOT,env=variables,stdout=log,stderr=subprocess.STDOUT)
            clients.append((proc,log,path))
        for i,(proc,log,path) in enumerate(clients):
            assert proc.wait(timeout=25)==0,str(path)
            log.close()
            text=path.read_text()
            assert ('FOREGRIP_NETWORK_PASS' if i==0 else 'FOREGRIP_OBSERVER_PASS') in text,str(path)
            assert not any(error in text for error in ['SCRIPT ERROR','Assertion failed','ObjectDB instances leaked']),str(path)
        text=server_path.read_text()
        assert not any(error in text for error in ['SCRIPT ERROR','above the MTU','Snapshot exceeds target']),str(server_path)
        print('FOREGRIP_TWO_CLIENT_PASS authority=ok owner=ok observer=ok packet_size=ok')
    finally:
        for proc,log,_ in clients:
            if proc.poll() is None:proc.kill();proc.wait()
            log.close()
        server.terminate()
        server.wait(timeout=10)
