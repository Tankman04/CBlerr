def main() -> int:
    token: str = "YOUR TOKEN" 
    chat_id: str = "YOUR_ID"
    text: str = "Hello+from+Flux+Micro-Binary!" 

    cmd_fmt: str = "curl.exe -s \"https://api.telegram.org/bot%s/sendMessage?chat_id=%s&text=%s\""

    cmd_buf: *u8 = malloc(1024)

    sprintf(cmd_buf, cmd_fmt.data, token.data, chat_id.data, text.data)

    print("Sending request to Telegram...")

    WinExec(cmd_buf, 0)

    free(cmd_buf)
    
    print("Done!")
    endofcode