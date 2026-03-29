unit AR.Console.Windows;

{******************************************************************************
  AR.Console.Windows — Windows console implementation

  Enables VT100 escape sequence processing and UTF-8 codepage on the
  Windows console.  Input uses ReadConsoleInput for raw key reads and
  maps virtual key codes to the KEY_* constants from AR.Console.Base.

  When compiled on a POSIX target this unit exposes nothing.

  (c) 2024 - Signal-Based LLM POC
******************************************************************************}

interface

uses
  AR.Console.Base
  {$IFDEF MSWINDOWS}
  , Winapi.Windows
  {$ENDIF};

{$IFDEF MSWINDOWS}
type
  TWindowsConsole = class(TConsoleBase)
  private
    FOrigOutMode: DWORD;
    FOrigInMode:  DWORD;
    FStdOut: THandle;
    FStdIn:  THandle;
  protected
    procedure PlatformInit; override;
    procedure PlatformShutdown; override;
    procedure PlatformDetectSize; override;
    function  PlatformReadKeyCode: Word; override;
    function  PlatformKeyPressed: Boolean; override;
    procedure PlatformEnableMouse; override;
    procedure PlatformDisableMouse; override;
  end;
{$ENDIF}

implementation

{$IFDEF MSWINDOWS}

const
  ENABLE_VIRTUAL_TERMINAL_PROCESSING = $0004;
  ENABLE_VIRTUAL_TERMINAL_INPUT      = $0200;
  ENABLE_QUICK_EDIT_MODE_            = $0040;  // underscore to avoid clash
  ENABLE_EXTENDED_FLAGS_             = $0080;
  ENABLE_MOUSE_INPUT_               = $0010;
  MOUSE_EVENT_                      = $0002;  // TInputRecord.EventType for mouse
  FROM_LEFT_1ST_BUTTON_PRESSED_     = $0001;
  RIGHTMOST_BUTTON_PRESSED_         = $0002;
  MOUSE_MOVED_                      = $0001;  // dwEventFlags
  MOUSE_WHEELED_                    = $0004;  // dwEventFlags

procedure TWindowsConsole.PlatformInit;
begin
  FStdOut := GetStdHandle(STD_OUTPUT_HANDLE);
  FStdIn  := GetStdHandle(STD_INPUT_HANDLE);

  if FStdOut <> INVALID_HANDLE_VALUE then
  begin
    GetConsoleMode(FStdOut, FOrigOutMode);
    SetConsoleMode(FStdOut, FOrigOutMode or ENABLE_VIRTUAL_TERMINAL_PROCESSING);
  end;

  if FStdIn <> INVALID_HANDLE_VALUE then
  begin
    GetConsoleMode(FStdIn, FOrigInMode);
    // Keep native input (virtual key codes for arrows etc.)
    // Do NOT enable ENABLE_VIRTUAL_TERMINAL_INPUT — it converts
    // arrow keys to ESC sequences which collide with KEY_ESCAPE.
    SetConsoleMode(FStdIn, FOrigInMode
                            and (not ENABLE_LINE_INPUT)
                            and (not ENABLE_ECHO_INPUT));
  end;

  SetConsoleOutputCP(CP_UTF8);
  SetConsoleCP(CP_UTF8);
end;

procedure TWindowsConsole.PlatformShutdown;
begin
  if FStdOut <> INVALID_HANDLE_VALUE then
    SetConsoleMode(FStdOut, FOrigOutMode);
  if FStdIn <> INVALID_HANDLE_VALUE then
    SetConsoleMode(FStdIn, FOrigInMode);
end;

procedure TWindowsConsole.PlatformDetectSize;
var
  Info: TConsoleScreenBufferInfo;
begin
  if GetConsoleScreenBufferInfo(FStdOut, Info) then
  begin
    ScreenWidth  := Info.srWindow.Right  - Info.srWindow.Left + 1;
    ScreenHeight := Info.srWindow.Bottom - Info.srWindow.Top  + 1;
  end;
end;

function TWindowsConsole.PlatformReadKeyCode: Word;
var
  Buf: TInputRecord;
  NumRead: DWORD;
  Evt: TMouseEvent;
  WheelDelta: SmallInt;
begin
  Result := KEY_NONE;
  repeat
    ReadConsoleInput(FStdIn, Buf, 1, NumRead);

    // ── Keyboard ────────────────────────────────────────────────────────
    if (Buf.EventType = KEY_EVENT) and Buf.Event.KeyEvent.bKeyDown then
    begin
      case Buf.Event.KeyEvent.wVirtualKeyCode of
        VK_UP:     Exit(KEY_UP);
        VK_DOWN:   Exit(KEY_DOWN);
        VK_LEFT:   Exit(KEY_LEFT);
        VK_RIGHT:  Exit(KEY_RIGHT);
        VK_HOME:   Exit(KEY_HOME);
        VK_END:    Exit(KEY_END_);
        VK_PRIOR:  Exit(KEY_PGUP);
        VK_NEXT:   Exit(KEY_PGDN);
        VK_DELETE: Exit(KEY_DELETE);
        VK_INSERT: Exit(KEY_INSERT);
        VK_F1:     Exit(KEY_F1);
        VK_F2:     Exit(KEY_F2);
        VK_F3:     Exit(KEY_F3);
        VK_F4:     Exit(KEY_F4);
        VK_F5:     Exit(KEY_F5);
        VK_F6:     Exit(KEY_F6);
        VK_F7:     Exit(KEY_F7);
        VK_F8:     Exit(KEY_F8);
        VK_F9:     Exit(KEY_F9);
        VK_F10:    Exit(KEY_F10);
        VK_F11:    Exit(KEY_F11);
        VK_F12:    Exit(KEY_F12);
        VK_RETURN: Exit(KEY_ENTER);
        VK_ESCAPE: Exit(KEY_ESCAPE);
        VK_TAB:    Exit(KEY_TAB);
        VK_BACK:   Exit(KEY_BACKSPACE);
      else
        if Buf.Event.KeyEvent.UnicodeChar <> #0 then
          Exit(Word(Buf.Event.KeyEvent.UnicodeChar));
      end;
    end

    // ── Mouse ───────────────────────────────────────────────────────────
    else if (Buf.EventType = MOUSE_EVENT_) and MouseActive then
    begin
      case Buf.Event.MouseEvent.dwEventFlags of
        0: // button press or release
        begin
          Evt.Col := Buf.Event.MouseEvent.dwMousePosition.X + 1;
          Evt.Row := Buf.Event.MouseEvent.dwMousePosition.Y + 1;
          if Buf.Event.MouseEvent.dwButtonState and FROM_LEFT_1ST_BUTTON_PRESSED_ <> 0 then
          begin
            Evt.Button  := mbLeft;
            Evt.Pressed := True;
          end
          else if Buf.Event.MouseEvent.dwButtonState and RIGHTMOST_BUTTON_PRESSED_ <> 0 then
          begin
            Evt.Button  := mbRight;
            Evt.Pressed := True;
          end
          else
          begin
            Evt.Button  := mbNone;
            Evt.Pressed := False;
          end;
          MouseState := Evt;
          Exit(KEY_MOUSE);
        end;
        MOUSE_WHEELED_:
        begin
          Evt.Col := Buf.Event.MouseEvent.dwMousePosition.X + 1;
          Evt.Row := Buf.Event.MouseEvent.dwMousePosition.Y + 1;
          WheelDelta := SmallInt(Buf.Event.MouseEvent.dwButtonState shr 16);
          if WheelDelta > 0 then
            Evt.Button := mbWheelUp
          else
            Evt.Button := mbWheelDown;
          Evt.Pressed := True;
          MouseState := Evt;
          Exit(KEY_MOUSE);
        end;
        // MOUSE_MOVED_ — silently ignored (consumed by the loop)
      end;
    end;
  until False;
end;

function TWindowsConsole.PlatformKeyPressed: Boolean;
var
  Buf: TInputRecord;
  Count, NumRead: DWORD;
begin
  // Drain events we ignore (mouse-move, key-up, focus, buffer-size) so
  // they don't cause the main loop to call ReadKeyCode and block.
  while True do
  begin
    GetNumberOfConsoleInputEvents(FStdIn, Count);
    if Count = 0 then Exit(False);

    PeekConsoleInput(FStdIn, Buf, 1, NumRead);
    if NumRead = 0 then Exit(False);

    // Key-down events are always interesting
    if (Buf.EventType = KEY_EVENT) and Buf.Event.KeyEvent.bKeyDown then
      Exit(True);

    // Mouse events: clicks and wheel are interesting, moves are not
    if (Buf.EventType = MOUSE_EVENT_) and MouseActive then
    begin
      if Buf.Event.MouseEvent.dwEventFlags <> MOUSE_MOVED_ then
        Exit(True);
      // Mouse-move — consume and continue
      ReadConsoleInput(FStdIn, Buf, 1, NumRead);
      Continue;
    end;

    // Anything else (key-up, focus, buffer-size, mouse-move) — consume
    ReadConsoleInput(FStdIn, Buf, 1, NumRead);
  end;
end;

procedure TWindowsConsole.PlatformEnableMouse;
var
  Mode: DWORD;
begin
  GetConsoleMode(FStdIn, Mode);
  Mode := (Mode or ENABLE_MOUSE_INPUT_ or ENABLE_EXTENDED_FLAGS_)
              and (not ENABLE_QUICK_EDIT_MODE_);
  SetConsoleMode(FStdIn, Mode);
end;

procedure TWindowsConsole.PlatformDisableMouse;
var
  Mode: DWORD;
begin
  GetConsoleMode(FStdIn, Mode);
  Mode := Mode and (not ENABLE_MOUSE_INPUT_);
  SetConsoleMode(FStdIn, Mode);
end;

{$ENDIF}

end.
