import sys
import websocket

def main(url, file):
    def on_message(ws, data):
        f.write(data)
    
    def on_close(ws):
        print("websocket disconnet")
        f.close()
    
    f = open(file, "wb")
    ws = websocket.WebSocketApp(url, on_message=on_message, on_close=on_close)
    print("websocket connect start")
    websocket.enableTrace(True)
    ws.run_forever(origin="https://twitcasting.tv/")
    f.close()

main(sys.argv[1], sys.argv[2])
