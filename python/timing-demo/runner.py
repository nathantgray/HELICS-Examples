import libtmux
from pathlib import Path

def main():
    session = libtmux.Server().list_sessions()[0]
    session.attached_window.split_window(vertical=False)
    cwd = Path.cwd()
    for i, p in enumerate(session.attached_window.children):
        p.clear()

        p.send_keys(f"python {cwd}/timing-federate{i+1}.py")
        p.enter()

if __name__ == "__main__":
    main()

