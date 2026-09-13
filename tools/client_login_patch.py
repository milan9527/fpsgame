"""Apply the account-memory changes to the deployed client source used by exporters."""
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]


def apply(client: Path):
    if client.resolve() != (ROOT / 'client').resolve():
        shutil.copy2(ROOT / 'client/scripts/remembered_login.gd', client / 'scripts/remembered_login.gd')
    path = client / 'scripts/interface.gd'
    text = path.read_text()
    if 'func restore_login()' not in text:
        text = text.replace('account_row.add_child(logout_button)', 'account_row.add_child(logout_button)\n\tvar forget_button := Button.new()\n\tforget_button.text = "FORGET LOGIN"\n\tforget_button.pressed.connect(forget_login)\n\taccount_row.add_child(forget_button)', 1)
        endpoint_line = next(line for line in text.splitlines() if line.startswith('\tendpoint = field('))
        text = text.replace(endpoint_line, endpoint_line + '\n\tendpoint.text_changed.connect(func(_value): restore_login())\n\trestore_login()', 1)
        text = text.replace('connection_cancel.disabled = true\n\tpassword.text = ""', 'connection_cancel.disabled = true\n\trestore_login()', 1)
        text += '''
func restore_login() -> void:
	var saved := preload("res://scripts/remembered_login.gd").read(endpoint.text)
	username.text = saved.username
	password.text = saved.password

func remember_login(server: String, name: String, secret: String) -> void:
	if preload("res://scripts/remembered_login.gd").remember(server, name, secret) != OK:
		status.text = "Signed in, but this device could not save the login."

func forget_login() -> void:
	var result := preload("res://scripts/remembered_login.gd").forget(endpoint.text)
	username.text = ""
	password.text = ""
	status.text = "Saved login cleared on this device." if result == OK else "Could not clear the saved login."
'''
        path.write_text(text)
    path = client / 'scripts/game.gd'
    text = path.read_text()
    if 'ui.remember_login(' not in text:
        text = text.replace('token = response.body.token', 'ui.remember_login(endpoint, username, password)\n\ttoken = response.body.token', 1)
        text = text.replace('func account_revoked() -> void:\n', 'func account_revoked() -> void:\n\tui.forget_login()\n', 1)
        text = text.replace('if code == 200 or code == 401:\n', 'if code == 200 or code == 401:\n\t\tui.forget_login()\n', 1)
        path.write_text(text)
