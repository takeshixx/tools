"""Extract PDF files from KLMviewer.exe after
decryption and decompression."""
from __future__ import print_function
import frida
import sys
import os.path
import string
import random

PDFS = {}


def random_string(n=8):
    return ''.join(random.choice(string.ascii_uppercase + string.digits) for _ in range(n))

    
def on_message(message, data):
    payload = message.get('payload')
    if not payload:
        print('no payload in message')
        return
    print('context: ' + str(payload['context']))
    if payload['type'] == 'ctx-lpfilename':
        path = data.replace(b'\0', b'')
        print('PDF path: ' + path.decode())
        PDFS[payload['context']] = path
    elif payload['type'] == 'data':
        if data.startswith(b'%PDF'):
            if not payload['context'] in PDFS.keys():
                print('context ' + str(payload['context']) + ' not found')
                filename = random_string() + '.pdf'
            else:
                filename = PDFS[payload['context']].split(b'\\')[-1]
                print('filename: ' + filename.decode())
            print('Found a PDF, dumping to ' + filename.decode())
            if os.path.isfile(filename):
                print('File already exists, skipping')
                return
            with open(filename, 'wb') as f:
                f.write(data)
        

def main(target_process):
    session = frida.attach(target_process)

    script = session.create_script("""
    var baseAddr = Module.findBaseAddress('KLMviewer.exe');
    console.log('KLMviewer.exe baseAddr: ' + baseAddr);

    var fz_open_file2 = baseAddr.add(0x0073690);
    var fz_open_buffer = baseAddr.add(0x00B50A0);
    
    Interceptor.attach(fz_open_file2, {
        onEnter: function (args) {
            console.log('[+] Called fz_open_file2: ' + fz_open_file2);
            var ctx = ptr(this.context.ecx);
            console.log('[+] Ctx: ' + ctx);
            var lpFileName = Memory.readByteArray(this.context.edx, 38);
            send({type: 'ctx-lpfilename', 'context': ctx}, lpFileName);
        }
    });

    Interceptor.attach(fz_open_buffer, {
        onEnter: function (args) {
            console.log('');
            console.log('[+] Called fz_open_buffer: ' + fz_open_buffer);
            var ctx = ptr(this.context.ecx);
            console.log('[+] Ctx: ' + ctx);
            console.log('[+] data pointer: ' + this.context.edx);
            var data_pointer = ptr(this.context.edx); 
            var pdf = Memory.readPointer(data_pointer.add(4));
            console.log('[+] pointer to pdf: ' + pdf);
            var size = Memory.readU32(data_pointer.add(12));
            console.log('[+] size of pdf: ' + size);
            var buf = Memory.readByteArray(pdf, size);
            send({type: 'data', 'context': ctx}, buf);
        },
    });
""")
    script.on('message', on_message)
    script.load()
    print("[!] Ctrl+D on UNIX, Ctrl+Z on Windows/cmd.exe to detach from instrumented program.\n\n")
    sys.stdin.read()
    session.detach()


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: %s <process name or PID>" % __file__)
        sys.exit(1)

    try:
        target_process = int(sys.argv[1])
    except ValueError:
        target_process = sys.argv[1]
    main(target_process) 
