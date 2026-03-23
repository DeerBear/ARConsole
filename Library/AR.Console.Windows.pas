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
  end;
{$ENDIF}

implementation

{$IFDEF MSWINDOWS}

const
  ENABLE_VIRTUAL_TERMINAL_PROCESSING = $0004;
  ENABLE_VIRTUAL_TERMINAL_INPUT      = $0200;

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
    FWidth  := Info.srWindow.Right  - Info.srWindow.Left + 1;
    FHeight := Info.srWindow.Bottom - Info.srWindow.Top  + 1;
  end;
end;

function TWindowsConsole.PlatformReadKeyCode: Word;
var
  Buf: TInputRecord;
  NumRead: DWORD;
begin
  Result := KEY_NONE;
  repeat
    ReadConsoleInput(FStdIn, Buf, 1, NumRead);
    if (Buf.EventType = KEY_EVENT) and Buf.Event.KeyEvent.bKeyDown then
    begin
      // Check virtual key code first for special keys
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
        // Printable character from UnicodeChar
        if Buf.Event.KeyEvent.UnicodeChar <> #0 then
          Exit(Word(Buf.Event.KeyEvent.UnicodeChar));
      end;
    end;
  until False;
end;

function TWindowsConsole.PlatformKeyPressed: Boolean;
var
  Count: DWORD;
begin
  GetNumberOfConsoleInputEvents(FStdIn, Count);
  Result := Count > 0;
end;

{$ENDIF}

end.
