import nigui
import port_checker
import std/net
import std/strutils
import std/re


let ipCharPattern = re"^[0-9.]*$"
let ipFullPattern = re"^(\d{1,3}\.){3}\d{1,3}$"

when isMainModule:

    app.init()

    var win = newWindow("Port Checker")
    win.width = 400
    win.height = 300
    win.centerOnScreen()
    win.resizable = false

    var container = newLayoutContainer(Layout_Vertical)
    container.xAlign = XAlign_Center
    win.add(container)

    var host_address = newTextBox()
    host_address.placeholder="Enter host address (e.g., 127.0.0.1)"
    host_address.text = "127.0.0.1"
    #host_address.width = 300
    host_address.height = 40
    host_address.fontSize = 17
    host_address.fontBold = true

    host_address.onTextChange = proc(event: TextChangeEvent) =
        let text = host_address.text
        if not text.match(ipCharPattern):
            var cleaned = ""
            for c in text:
                if c in {'0'..'9', '.'}:
                    cleaned.add(c)
            host_address.text = cleaned
            host_address.selectionStart = cleaned.len
            host_address.selectionEnd = cleaned.len
        else:
            if text.match(ipFullPattern):
                echo "Looks like a valid IPv4 shape: ", text

    container.add(host_address)

    var port_number = newTextBox()
    port_number.placeholder = "Enter port number (e.g., 8080)"
    #port_number.width = 300
    port_number.height = 40
    port_number.fontSize = 17
    port_number.fontBold = true

    port_number.onTextChange = proc(event: TextChangeEvent) =
        var cleaned = ""
        for c in port_number.text:
            if c in {'0'..'9'}:
                cleaned.add(c)
        if cleaned != port_number.text:
            port_number.text = cleaned
            port_number.selectionStart = cleaned.len
            port_number.selectionEnd = cleaned.len


    container.add(port_number)

    var btn = newButton("Check Port")
    container.add(btn)

    var response = newTextArea()
    response.editable = false
    response.fontSize = 17
    container.add(response)

    btn.onClick = proc(event: ClickEvent) =
        try:
            var host = host_address.text
            var port = Port(parseInt(port_number.text))
            var result = port_checker.isPortInUse(host, port)
            response.text = "Port is " & (if result: "in use" else: "free")
        except ValueError:
            response.text = "Please input a valid port number."
        except:
            response.text = "Error: " & getCurrentExceptionMsg()

    win.show()
    app.run()