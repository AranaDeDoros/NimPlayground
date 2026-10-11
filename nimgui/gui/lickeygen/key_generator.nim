import nigui
import keygen
import os

const BGCOLOR = Color(red: 182, green: 178, blue: 188, alpha: byte(0.09 * 255))
const TEXTCOLOR = Color(red: 57, green: 60, blue: 65, alpha: byte(1 * 255))
const FONT_FAMILY = "IBM Plex Mono"

proc applyFont[T](control: T, bold = false) =
    control.fontFamily = FONT_FAMILY
    control.fontBold = bold

when isMainModule:

    app.init()

    var win = newWindow("NimKey Genie")
    win.width = 500
    win.height = 350
    win.centerOnScreen()
    win.resizable = false

    var area = newLayoutContainer(Layout_Vertical)
    area.widthMode = WidthMode_Fill
    area.height=350
    area.xAlign = XAlign_Center
    area.yAlign = YAlign_Center
    area.backgroundColor = BGCOLOR

    win.add(area)

    var label : Label = newLabel("Generate a key")
    var welcome : Label = newLabel("Welcome to NimKey Genie!")
    welcome.fontSize=16
    welcome.width = 350
    welcome.backgroundColor = BGCOLOR
    welcome.textColor = TEXTCOLOR
    welcome.xTextAlign = XTextAlign_Center
    welcome.fontBold= true
    label.fontSize=16
    label.width = 350
    label.backgroundColor = BGCOLOR
    label.textColor = TEXTCOLOR
    label.xTextAlign = XTextAlign_Center
    label.fontBold= true
    var key = newTextBox()
    key.width= 400
    key.height= 100
    key.editable=false
    key.fontSize= 16
    key.textColor = TEXTCOLOR
    key.fontSize = 20
    var btn: Button = newButton("new")
    btn.textColor=TEXTCOLOR
    btn.setSize(120,100)
    btn.fontSize=16
    var save: Button = newButton("save")
    save.textColor=TEXTCOLOR
    save.setSize(120,100)
    save.fontSize=16
    applyFont(area)
    area.add(welcome)
    area.add(label)
    area.add(key)

    var buttons = newLayoutContainer(Layout_Horizontal)
    buttons.widthMode = WidthMode_Fill
    buttons.xAlign = XAlign_Center
    buttons.yAlign = YAlign_Top
    buttons.backgroundColor = BGCOLOR
    buttons.spacing= 20
    buttons.add(btn)
    buttons.add(save)

    area.add(buttons)

    btn.onClick = proc(event: ClickEvent) =
        try:
            var result : string = generateLicenseKey()
            key.text = result
            key.focus()
            key.selectionStart = 0
            key.selectionEnd= key.text.len
        except:
            key.text = "Error: " & getCurrentExceptionMsg()

    save.onClick = proc(event: ClickEvent) =
        if key.text.len == 0:
            alert(win, "No license key to save. Please generate a key first.")
            return
        let d = newSaveFileDialog()
        d.title = "Save License Key"
        d.directory = getCurrentDir()
        d.defaultExtension = "nk"
        d.defaultName = "license_key"
        d.run()
        if d.file.len == 0:
            return  # user cancelled
        try:
            writeFile(d.file, key.text)
            alert(win, "License key saved to: " & d.file, "Success")
        except:
            alert(win, "Error saving license key: " & getCurrentExceptionMsg())

    let iconFile = getAppDir() / "icon.ico"
    if fileExists(iconFile):
        win.iconPath = iconFile
    else:
        echo "Icon not found at: ", iconFile

    win.onKeyDown = proc(event: KeyboardEvent) =
        if event.key == Key_Escape:
            win.dispose()
    win.show()
    btn.focus()
    app.run()
