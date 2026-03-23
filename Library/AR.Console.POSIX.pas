unit AR.Console.POSIX;

{******************************************************************************
  AR.Console.POSIX — POSIX (Linux / macOS) console implementation

  Switches the terminal to raw mode via termios and restores it on
  shutdown.  Terminal size is detected via ioctl(TIOCGWINSZ).

  ReadKeyCode parses CSI escape sequences (ESC [ ...) to produce the
  KEY_* constants from AR.Console.Base.

  When compiled on a Windows target this unit exposes nothing.

  (c) 2024 - Signal-Based LLM POC
******************************************************************************}

interface

uses
  AR.Console.Base
  {$IFDEF POSIX}
  , Posix.Base, Posix.Termios, Posix.Unistd, Posix.SysTypes
  {$ENDIF};

{$IFDEF POSIX}
type
  TPosixConsole = class(TConsoleBase)
  private
    FOrigTermios: termios;
    function ReadByte: Byte;
    function ReadByteTimeout(ATimeoutDs: Byte; out AByte: Byte): Boolean;
  protected
    procedure PlatformInit; override;
    procedure PlatformShutdown; override;
    procedure PlatformDetectSize; override;
    function  PlatformReadKeyCode: Word; override;
    function  PlatformKeyPressed: Boolean; override;
  end;
{$ENDIF}

implementation

{$IFDEF POSIX}

// ── ioctl / winsize ─────────────────────────────────────────────────────────

type
  TWinSize = record
    ws_row:    UInt16;
    ws_col:    UInt16;
    ws_xpixel: UInt16;
    ws_ypixel: UInt16;
  end;

const
  {$IFDEF LINUX}
  TIOCGWINSZ = $5413;
  {$ENDIF}
  {$IFDEF MACOS}
  TIOCGWINSZ = $40087468;
  {$ENDIF}

function ioctl(fd: Integer; request: UInt64): Integer; cdecl; varargs;
  external libc name 'ioctl';

// ── TPosixConsole ───────────────────────────────────────────────────────────

procedure TPosixConsole.PlatformInit;
var
  Raw: termios;
begin
  tcgetattr(STDIN_FILENO, @FOrigTermios);
  Raw := FOrigTermios;

  Raw.c_iflag := Raw.c_iflag and not (BRKINT or ICRNL or INPCK or ISTRIP or IXON);
  Raw.c_cflag := Raw.c_cflag or CS8;
  Raw.c_lflag := Raw.c_lflag and not (ECHO or ICANON or ISIG or IEXTEN);
  Raw.c_cc[VMIN]  := 1;
  Raw.c_cc[VTIME] := 0;

  tcsetattr(STDIN_FILENO, TCSAFLUSH, @Raw);
end;

procedure TPosixConsole.PlatformShutdown;
begin
  tcsetattr(STDIN_FILENO, TCSAFLUSH, @FOrigTermios);
end;

procedure TPosixConsole.PlatformDetectSize;
var
  WS: TWinSize;
begin
  if ioctl(STDIN_FILENO, TIOCGWINSZ, @WS) = 0 then
  begin
    FWidth  := WS.ws_col;
    FHeight := WS.ws_row;
  end;
end;

function TPosixConsole.ReadByte: Byte;
begin
  Result := 0;
  Posix.Unistd.__read(STDIN_FILENO, @Result, 1);
end;

function TPosixConsole.ReadByteTimeout(ATimeoutDs: Byte; out AByte: Byte): Boolean;
var
  Saved, Tmp: termios;
  N: Integer;
begin
  // Temporarily set VMIN=0 and VTIME for a short timeout
  tcgetattr(STDIN_FILENO, @Saved);
  Tmp := Saved;
  Tmp.c_cc[VMIN]  := 0;
  Tmp.c_cc[VTIME] := ATimeoutDs;  // deciseconds
  tcsetattr(STDIN_FILENO, TCSANOW, @Tmp);

  AByte := 0;
  N := Posix.Unistd.__read(STDIN_FILENO, @AByte, 1);

  tcsetattr(STDIN_FILENO, TCSANOW, @Saved);
  Result := N > 0;
end;

function TPosixConsole.PlatformReadKeyCode: Word;
var
  B, B2: Byte;
begin
  B := ReadByte;

  // Not an escape? Return as-is.
  if B <> $1B then
    Exit(Word(B));

  // ESC received — try to read '[' within a short timeout.
  // If nothing follows, it's a bare Escape press.
  if not ReadByteTimeout(1, B2) then
    Exit(KEY_ESCAPE);

  if B2 = Ord('[') then
  begin
    // CSI sequence: ESC [ <code>
    B2 := ReadByte;
    case Chr(B2) of
      'A': Exit(KEY_UP);
      'B': Exit(KEY_DOWN);
      'C': Exit(KEY_RIGHT);
      'D': Exit(KEY_LEFT);
      'H': Exit(KEY_HOME);
      'F': Exit(KEY_END_);
      '1'..'9':
      begin
        // Extended: ESC [ <digit> ~ or ESC [ 1 ; ... ~
        // Read until '~' or a letter
        var Num: Integer := Ord(B2) - Ord('0');
        B2 := ReadByte;
        // Could be a second digit
        if (B2 >= Ord('0')) and (B2 <= Ord('9')) then
        begin
          Num := Num * 10 + (Ord(B2) - Ord('0'));
          B2 := ReadByte;  // Should be '~'
        end;
        if Chr(B2) = '~' then
        begin
          case Num of
            1:  Exit(KEY_HOME);
            2:  Exit(KEY_INSERT);
            3:  Exit(KEY_DELETE);
            4:  Exit(KEY_END_);
            5:  Exit(KEY_PGUP);
            6:  Exit(KEY_PGDN);
            11: Exit(KEY_F1);
            12: Exit(KEY_F2);
            13: Exit(KEY_F3);
            14: Exit(KEY_F4);
            15: Exit(KEY_F5);
            17: Exit(KEY_F6);
            18: Exit(KEY_F7);
            19: Exit(KEY_F8);
            20: Exit(KEY_F9);
            21: Exit(KEY_F10);
            23: Exit(KEY_F11);
            24: Exit(KEY_F12);
          end;
        end;
        // Unknown CSI — swallow and return nothing useful
        Exit(KEY_NONE);
      end;
    else
      // Unknown CSI code — ignore
      Exit(KEY_NONE);
    end;
  end
  else if B2 = Ord('O') then
  begin
    // SS3 sequences: ESC O <code> (some terminals for F1-F4)
    B2 := ReadByte;
    case Chr(B2) of
      'P': Exit(KEY_F1);
      'Q': Exit(KEY_F2);
      'R': Exit(KEY_F3);
      'S': Exit(KEY_F4);
      'H': Exit(KEY_HOME);
      'F': Exit(KEY_END_);
    else
      Exit(KEY_NONE);
    end;
  end;

  // ESC + some other char — treat as Alt+key, but we don't handle that
  Exit(KEY_NONE);
end;

function TPosixConsole.PlatformKeyPressed: Boolean;
var
  Saved, Tmp: termios;
  B: Byte;
  N: Integer;
begin
  tcgetattr(STDIN_FILENO, @Saved);
  Tmp := Saved;
  Tmp.c_cc[VMIN]  := 0;
  Tmp.c_cc[VTIME] := 0;
  tcsetattr(STDIN_FILENO, TCSANOW, @Tmp);
  N := Posix.Unistd.__read(STDIN_FILENO, @B, 1);
  tcsetattr(STDIN_FILENO, TCSANOW, @Saved);
  Result := N > 0;
end;

{$ENDIF}

end.
