using { /Fortnite.com/UI }
using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Verse.org/Simulation }
using { /Verse.org/Colors }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/Diagnostics }

# Follow Hyperbit on Twitter / X for more Free Content: https://x.com/hyperbitfn
# Subscribe to the Hyperbit FN Youtube Channel: https://www.youtube.com/@HyperbitFN
# Join the Hyperbit Discord Channel: https://discord.gg/hyperbit

keypad_device := class(creative_device):
    @editable       Password : string = ""
    @editable       AllowedAttempts : int = 3
    @editable       InteractionButton : button_device = button_device{}
    @editable       PasswordGuessedEventChannel : channel_device = channel_device{}
    @editable       PasswordIncorrectEventChannel : channel_device = channel_device{}
    @editable       MaxAttemptsFailedEventChannel : channel_device = channel_device{}
    
    @editable       KeypadWidgetSettings : keypad_widget_settings = keypad_widget_settings{}

    var AgentKeypadWidgetsMap : [agent]keypad_widget = map{}

    OnBegin<override>()<suspends> : void =
        Update()

    Update()<suspends> : void =
        sync:
            loop: <# When player leaves game, cleanup their widget #>
                Player := GetPlayspace().PlayerRemovedEvent().Await()
                if ( LeavingAgent := agent[Player], Widget := AgentKeypadWidgetsMap[LeavingAgent]):
                    Widget.Destroy()
                    for:
                        Agent -> KeypadWidget : AgentKeypadWidgetsMap
                        Agent <> LeavingAgent
                        set AgentKeypadWidgetsMap[Agent] = Widget
                    do:

            loop: <# Main Event Loop #>
                Agent := InteractionButton.InteractedWithEvent.Await()
                if (KeypadWidget := AgentKeypadWidgetsMap[Agent]):
                    if ( not KeypadWidget.IsDisplayed[]):
                        spawn { AwaitKeypadEvents(Agent, KeypadWidget)}
                else:
                    NewKeypadWidget := keypad_widget{}
                    NewKeypadWidget.Init(KeypadWidgetSettings)
                    if ( set AgentKeypadWidgetsMap[Agent] = NewKeypadWidget):
                        spawn { AwaitKeypadEvents(Agent, NewKeypadWidget)}
                  
    AwaitKeypadEvents(Agent : agent, KeypadWidget : keypad_widget)<suspends> : void =
        if ( Player := player[Agent]):
            var CurrentGuess : string = ""
            var CurrentAttempts : int = 0
            KeypadWidget.SetText(CurrentGuess)
            KeypadWidget.Display(Player)
            race:
                KeypadWidget.DestroyedEvent.Await()
                KeypadWidget.RemovedEvent.Await()
                block:
                    if ( FortCharacter := Agent.GetFortCharacter[]):
                        FortCharacter.EliminatedEvent().Await()
                        KeypadWidget.Remove(Player)
                    else:
                        Sleep(Inf)
                block:
                    KeypadWidget.ExitButtonPressedEvent.Await()
                    KeypadWidget.Remove(Player)
                
                loop:
                    KeypadWidget.EnterButtonPressedEvent.Await()
                    if ( CurrentGuess = Password):
                        Print("Correct!")
                        PasswordGuessedEventChannel.Transmit(option{Agent})
                        var DisplayText : string = ""
                        for ( Index->Char : "Correct!"):
                            set DisplayText = DisplayText + array{Char}
                            KeypadWidget.SetText(DisplayText)
                            Sleep(0.1)
                        Sleep(0.5)
                        KeypadWidget.Remove(Player)
                        break
                    else:
                        Print("Incorrect!")
                        set CurrentAttempts = CurrentAttempts + 1
                        PasswordIncorrectEventChannel.Transmit(option{Agent})
                        KeypadWidget.SetText("Incorrect!")
                        if ( CurrentAttempts = AllowedAttempts):
                            MaxAttemptsFailedEventChannel.Transmit(option{Agent})
                            var DisplayText : string = ""
                            for ( Index->Char : "Failed!"):
                                set DisplayText = DisplayText + array{Char}
                                KeypadWidget.SetText(DisplayText)
                                Sleep(0.1)
                            Sleep(0.5)
                            KeypadWidget.Remove(Player)
                            break
                loop:
                    KeypadWidget.BackButtonPressedEvent.Await()
                    set CurrentGuess = CurrentGuess.Slice[0, CurrentGuess.Length - 1] or ""
                    KeypadWidget.SetText(CurrentGuess)

                loop:
                    Number := KeypadWidget.NumberButtonPressedEvent.Await()
                    if ( CurrentGuess.Length < Password.Length):
                        set CurrentGuess = CurrentGuess + ToString(Number)
                        KeypadWidget.SetText(CurrentGuess)

keypad_widget := class:
    Canvas : canvas = canvas{}
    DisplayedEvent : event(agent) = event(agent){}
    RemovedEvent : event(agent) = event(agent){}
    DestroyedEvent : event() = event(){}

    NumberButtonPressedEvent<public> : event(int) = event(int){}
    BackButtonPressedEvent<public> : event() = event(){}
    EnterButtonPressedEvent<public> : event() = event(){}
    ExitButtonPressedEvent<public> : event() = event(){}

    BaseOutlineColorBlock : color_block = color_block{}
    BaseColorBlock : color_block = color_block{DefaultDesiredSize := vector2{ X := 512.0, Y := 768.0}}


    TextAreaColorBlock : color_block = color_block{}
    TextAreaOutlineColorBlock : color_block = color_block{}

    InputTextBlock : text_block = text_block{}


    var IsWidgetDisplayed : logic = false
    var RootWidget : widget = overlay{}

    var BackButton : text_button_base = button_quiet{}
    var EnterButton : text_button_base = button_quiet{}
    var ExitButton : text_button_base = button_quiet{}
    var NumberButtons : []text_button_base = array{}

    Init(WidgetSettings : keypad_widget_settings) : void =
        case(WidgetSettings.KeypadButtonType):
            keypad_button_type.ButtonQuiet => 
                set NumberButtons = for ( I := 0..9) do button_quiet{DefaultText := ToMessage("{I}")}
                set BackButton = button_quiet{DefaultText := ToMessage("❌")}
                set EnterButton = button_quiet{DefaultText := ToMessage("✔")}
                set ExitButton = button_quiet{DefaultText := ToMessage("Exit")}
            keypad_button_type.ButtonLoud => 
                set NumberButtons = for ( I := 0..9) do button_loud{DefaultText := ToMessage("{I}")}
                set BackButton = button_loud{DefaultText := ToMessage("❌")}
                set EnterButton = button_loud{DefaultText := ToMessage("✔")}
                set ExitButton = button_loud{DefaultText := ToMessage("Exit")}
        BaseColorBlock.SetColor(WidgetSettings.KeypadBaseColor)
        BaseOutlineColorBlock.SetColor(WidgetSettings.KeypadBaseOutlineColor)
        TextAreaColorBlock.SetColor(WidgetSettings.TextAreaColor)
        TextAreaOutlineColorBlock.SetColor(WidgetSettings.TextAreaOutlineColor)
        InputTextBlock.SetTextColor(WidgetSettings.KeypadTextSettings.TextColor)
        InputTextBlock.SetShadowColor(WidgetSettings.KeypadTextSettings.TextShadowColor)
        InputTextBlock.SetShadowOpacity(WidgetSettings.KeypadTextSettings.TextShadowOpacity)
        InputTextBlock.SetShadowOffset(option{WidgetSettings.KeypadTextSettings.TextShadowOffset})

        for ( Number->Button : NumberButtons) do spawn { AwaitNumberButtonPress(Button, Number)}
        spawn { AwaitButtonPress(BackButton, BackButtonPressedEvent) }
        spawn { AwaitButtonPress(EnterButton, EnterButtonPressedEvent) }
        spawn { AwaitButtonPress(ExitButton, ExitButtonPressedEvent) }
            
        Row1 := CreateButtonRow((NumberButtons[7] or button_quiet{}, NumberButtons[8] or button_quiet{}, NumberButtons[9] or button_quiet{}))
        Row2 := CreateButtonRow((NumberButtons[4] or button_quiet{}, NumberButtons[5] or button_quiet{}, NumberButtons[6] or button_quiet{}))
        Row3 := CreateButtonRow((NumberButtons[1] or button_quiet{}, NumberButtons[2] or button_quiet{}, NumberButtons[3] or button_quiet{}))
        Row4 := CreateButtonRow((BackButton, NumberButtons[0] or button_quiet{}, EnterButton))

        set RootWidget = overlay:
            Slots := array:
                overlay_slot: <# Base outline / border #>
                    Widget := BaseOutlineColorBlock
                    HorizontalAlignment := horizontal_alignment.Fill
                    VerticalAlignment := vertical_alignment.Fill
                    Padding := margin{ Left := -7.0, Top := -7.0, Right := -7.0, Bottom := -7.0}
                overlay_slot: <# Base color / rectangle #>
                    Widget := BaseColorBlock

                overlay_slot: <# Main Grid Buttons #>
                    VerticalAlignment := vertical_alignment.Top
                    Padding := margin{ Top := 160.0}
                    Widget := stack_box:
                        Orientation := orientation.Vertical
                        Slots := array:
                            Row1
                            Row2
                            Row3
                            Row4

                overlay_slot: <# Input Text #>
                    HorizontalAlignment := horizontal_alignment.Fill
                    VerticalAlignment := vertical_alignment.Top
                    Padding := margin{Left := 50.0, Top := 50.0, Right := 50.0}
                    Widget := overlay:
                        Slots := array:
                            overlay_slot: <# Border / Outline #>
                                Widget := BaseOutlineColorBlock
                                HorizontalAlignment := horizontal_alignment.Fill
                                VerticalAlignment := vertical_alignment.Fill
                                Padding := margin{Left := -7.0, Top := -7.0, Bottom := -7.0, Right := -7.0}
                                
                            overlay_slot:<# Base Input Text Area Color #>
                                Widget := TextAreaColorBlock
                                HorizontalAlignment := horizontal_alignment.Fill

                            overlay_slot: <# Input Text #>
                                Widget := InputTextBlock

                overlay_slot: <# Exit Button #>
                    Widget := ExitButton
                    HorizontalAlignment := horizontal_alignment.Fill
                    VerticalAlignment := vertical_alignment.Bottom
                    Padding := margin{Bottom := -90.0}
        Canvas.AddWidget(GetDisplayCanvasSlot())

    CreateButtonRow(Buttons : tuple(text_button_base, text_button_base, text_button_base) ) : stack_box_slot = 
        stack_box_slot:
            VerticalAlignment := vertical_alignment.Top
            Padding := margin{ Bottom := 50.0}
            Widget := stack_box:
                Orientation := orientation.Horizontal
                Slots := array:
                    stack_box_slot: <# Button 1 #>
                        Padding := margin{Left := 30.0, Right := 30.0}
                        Widget := overlay:
                            Slots := array:
                                overlay_slot:
                                    Widget := color_block{DefaultDesiredSize := vector2{X := 100.0, Y := 100.0}, DefaultOpacity := 0.0}
                                overlay_slot:
                                    Widget := Buttons(0)
                                    HorizontalAlignment := horizontal_alignment.Fill
                                    VerticalAlignment := vertical_alignment.Fill
                    stack_box_slot: <# Button 2 #>
                        Padding := margin{Left := 30.0, Right := 30.0}
                        Widget := overlay:
                            Slots := array:
                                overlay_slot:
                                    Widget := color_block{DefaultDesiredSize := vector2{X := 100.0, Y := 100.0}, DefaultOpacity := 0.0}
                                overlay_slot:
                                    Widget := Buttons(1)
                                    HorizontalAlignment := horizontal_alignment.Fill
                                    VerticalAlignment := vertical_alignment.Fill
                    stack_box_slot: <# Button 3 #>
                        Padding := margin{Left := 30.0, Right := 30.0}
                        Widget := overlay:
                            Slots := array:
                                overlay_slot:
                                    Widget := color_block{DefaultDesiredSize := vector2{X := 100.0, Y := 100.0}, DefaultOpacity := 0.0}
                                overlay_slot:
                                    Widget := Buttons(2)
                                    HorizontalAlignment := horizontal_alignment.Fill
                                    VerticalAlignment := vertical_alignment.Fill
                       
    Destroy() : void =
        DestroyedEvent.Signal()
        set RootWidget = overlay{}

    Display(Player : player) : void =
        if ( PlayerUI := GetPlayerUI[Player]):
            DisplayedEvent.Signal(Player)
            PlayerUI.AddWidget(Canvas, player_ui_slot{InputMode := ui_input_mode.All})
            set IsWidgetDisplayed = true

    AwaitButtonPress(Button : text_button_base, Event : event())<suspends> : void =
        race:
            DestroyedEvent.Await()
            loop:
                Button.OnClick().Await()
                Event.Signal()

    AwaitNumberButtonPress(Button : text_button_base, Number : int)<suspends> : void =
        race:
            DestroyedEvent.Await()
            loop:
                Button.OnClick().Await()
                NumberButtonPressedEvent.Signal(Number)

    Remove(Player : player) : void =
        RemovedEvent.Signal(Player)
        if ( PlayerUI := GetPlayerUI[Player]):
            PlayerUI.RemoveWidget(Canvas)
            set IsWidgetDisplayed = false

    SetText(Text : string) : void = InputTextBlock.SetText(ToMessage(Text))

    IsDisplayed()<transacts><decides> : void = IsWidgetDisplayed?
    GetRootWidget() : widget = RootWidget
    GetCanvas() : canvas = Canvas
    GetDisplayCanvasSlot() : canvas_slot = 
        canvas_slot:
            Widget := RootWidget
            Anchors := anchors{Minimum := vector2{ X := 0.5, Y := 0.5}, Maximum := vector2{ X := 0.5, Y := 0.5}}
            Alignment := vector2{X := 0.5, Y := 0.5}


keypad_widget_settings := class<concrete>:
    @editable       KeypadButtonType : keypad_button_type = keypad_button_type.ButtonQuiet
    @editable       KeypadBaseColor : color = MakeColorFromHex("#424242FF")
    @editable       KeypadBaseOutlineColor : color = MakeColorFromHex("#00000000")
    @editable       KeypadTextSettings : keypad_widget_text_settings = keypad_widget_text_settings{}
    @editable       TextAreaColor : color = NamedColors.White
    @editable       TextAreaOutlineColor : color = color{}
    
keypad_widget_text_settings := class<concrete>:
    @editable       TextColor : color = color{}
    @editable       TextShadowOffset : vector2 = vector2{}
    @editable       TextShadowOpacity : type{_X : float where _X >= 0.0, _X <= 1.0} = 0.0
    @editable       TextShadowColor : color = color{}

keypad_button_type := enum:
    ButtonLoud
    ButtonQuiet

ToMessage<localizes>(Str : string) : message = "{Str}"
