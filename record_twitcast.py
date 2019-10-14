import sys
import time
import websocket

def main(url, file):
    def on_message(ws, data):
        f.write(data)
    
    def on_close(ws):
        print("[" + time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()) + "] websocket disconnect")
        f.close()
    
    print("[" + time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()) + "] open " + file)
    f = open(file, "wb")
    ws = websocket.WebSocketApp(url, on_message=on_message, on_close=on_close)
    print("[" + time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()) + "] websocket connect")
    websocket.enableTrace(True)
    ws.run_forever(origin="https://twitcasting.tv/")
    print("[" + time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()) + "] close " + file)
    f.close()

main(sys.argv[1], sys.argv[2])
