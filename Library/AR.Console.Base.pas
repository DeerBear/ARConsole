unit AR.Console.Base;

{******************************************************************************
  AR.Console.Base — Abstract types, constants, and base classes for TUI

  This unit contains everything that is platform-independent:

    - TConsoleColor enum and ANSI SGR codes
    - TBoxStyle, TBoxChars, and Unicode box-drawing constants
    - Extended key codes (arrows, Enter, Escape, Tab)
    - TMenuItem record
    - TConsoleBase — abstract base class declaring the full console API
    - TConsoleLayout — abstract layout base class

  Concrete layouts (TFrameLayout, TSingleFrameLayout, TDoubleFrameLayout,
  TTabbedLayout, TTabBar) and the layout registry live in
  AR.Console.Layouts.

  Platform units (AR.Console.Windows, AR.Console.POSIX) subclass
  TConsoleBase with their Init/Shutdown/DetectSize/ReadKeyCode/KeyPressed.

  (c) 2024 - Signal-Based LLM POC
******************************************************************************}

interface

uses
  System.SysUtils, System.Classes;

type
  // ── Colour palette (foreground) ───────────────────────────────────────────
  TConsoleColor = (
    ccDefault,
    ccBlack,
    ccRed,
    ccGreen,
    ccYellow,
    ccBlue,
    ccMagenta,
    ccCyan,
    ccWhite,
    ccGray,
    ccBrightRed,
    ccBrightGreen,
    ccBrightYellow,
    ccBrightBlue,
    ccBrightMagenta,
    ccBrightCyan,
    ccBrightWhite
  );

  // ── Box-drawing style ─────────────────────────────────────────────────────
  TBoxStyle = (bsSingle, bsDouble);

  TBoxChars = record
    TopLeft, TopRight, BottomLeft, BottomRight: Char;
    Horizontal, Vertical: Char;
    TeeLeft, TeeRight, TeeTop, TeeBottom: Char;
    Cross: Char;
  end;

  // ── Menu item for simple selection lists ──────────────────────────────────
  TMenuItem = record
    Key:   Char;
    Label_: string;
  end;

  // Forward
  TConsoleBase = class;

  // ── Abstract layout ─────────────────────────────────────────────────────
  TConsoleLayout = class abstract
  protected
    FConsole: TConsoleBase;
    FBoxStyle: TBoxStyle;
  public
    constructor Create(AConsole: TConsoleBase; AStyle: TBoxStyle = bsDouble); virtual;
    procedure DrawFrame; virtual; abstract;
    // Draw a miniature preview of this layout at the given position
    procedure DrawPreview(ALeft, ATop, AWidth, AHeight: Integer); virtual; abstract;
    procedure GetContentArea(out ACol, ARow, AWidth, AHeight: Integer); virtual; abstract;
    function  GetInputRow: Integer; virtual; abstract;
    function  GetInputCol: Integer; virtual; abstract;
    procedure GetTitleArea(out ACol, ARow, AWidth: Integer); virtual; abstract;
    property  BoxStyle: TBoxStyle read FBoxStyle write FBoxStyle;
  end;

  // ── Abstract console base ───────────────────────────────────────────────
  //   Concrete layouts live in AR.Console.Layouts.
  TConsoleBase = class abstract
  private
    FLayout: TConsoleLayout;
  protected
    FInitialised: Boolean;
    FWidth:  Integer;
    FHeight: Integer;

    // {platform} — subclasses must implement these
    procedure PlatformInit; virtual; abstract;
    procedure PlatformShutdown; virtual; abstract;
    procedure PlatformDetectSize; virtual; abstract;
    function  PlatformReadKeyCode: Word; virtual; abstract;
    function  PlatformKeyPressed: Boolean; virtual; abstract;
  public
    constructor Create;
    destructor Destroy; override;

    // ── Lifecycle ─────────────────────────────────────────────────────────
    procedure Init;
    procedure Shutdown;

    // ── Layout ────────────────────────────────────────────────────────────
    procedure SetLayout(ALayout: TConsoleLayout);
    procedure ClearContent;   // Blanks the layout's content area
    procedure ClearInput;     // Blanks the layout's input row
    // Print relative to content area (1-based offsets within content region)
    procedure PrintContent(ACol, ARow: Integer; const AText: string);
    // Show text at the input row (clears it first)
    procedure ShowStatus(const AText: string);
    // Show prompt at input row, read a line, return text.
    // AExitKey receives the key that ended input (KEY_ENTER, KEY_LEFT, etc.)
    function  PromptInput(const APrompt: string; out AExitKey: Word): string; overload;
    function  PromptInput(const APrompt: string): string; overload;
    property  Layout: TConsoleLayout read FLayout;

    // ── Screen ────────────────────────────────────────────────────────────
    procedure Clear;
    procedure MoveTo(ACol, ARow: Integer);
    procedure HideCursor;
    procedure ShowCursor;
    function  Width: Integer;
    function  Height: Integer;
    procedure RefreshSize;

    // ── Output ────────────────────────────────────────────────────────────
    procedure SetColor(AFg: TConsoleColor);
    procedure ResetColor;
    procedure Print(const AText: string);
    procedure PrintLn(const AText: string);
    procedure PrintAt(ACol, ARow: Integer; const AText: string);

    // ── Box drawing ───────────────────────────────────────────────────────
    class function BoxChars(AStyle: TBoxStyle): TBoxChars; static;
    procedure DrawBox(ALeft, ATop, AWidth, AHeight: Integer;
                      AStyle: TBoxStyle = bsDouble);
    procedure DrawHLine(ALeft, ARight, ARow: Integer;
                        AStyle: TBoxStyle = bsDouble);

    // ── Input ─────────────────────────────────────────────────────────────
    function  ReadKey: Char;          // Printable chars only (blocks on special)
    function  ReadKeyCode: Word;      // Extended: returns KEY_* constants
    function  ReadLine: string; overload;
    function  ReadLine(out AExitKey: Word): string; overload;
    function  KeyPressed: Boolean;

    // ── High-level: menu ──────────────────────────────────────────────────
    function ShowMenu(ALeft, ATop: Integer;
                      const ATitle: string;
                      const AItems: array of TMenuItem;
                      AStyle: TBoxStyle = bsDouble): Integer;
  end;

// ── Extended key code constants ─────────────────────────────────────────────
//   Printable characters are their ordinal value (0..$FF).
//   Special keys live in the $F0xx range to avoid collisions.
const
  KEY_NONE      = $0000;
  KEY_ENTER     = $000D;
  KEY_TAB       = $0009;
  KEY_ESCAPE    = $001B;
  KEY_BACKSPACE = $0008;

  KEY_UP        = $F001;
  KEY_DOWN      = $F002;
  KEY_LEFT      = $F003;
  KEY_RIGHT     = $F004;
  KEY_HOME      = $F005;
  KEY_END_      = $F006;
  KEY_PGUP      = $F007;
  KEY_PGDN      = $F008;
  KEY_DELETE     = $F009;
  KEY_INSERT     = $F00A;

  KEY_F1        = $F010;
  KEY_F2        = $F011;
  KEY_F3        = $F012;
  KEY_F4        = $F013;
  KEY_F5        = $F014;
  KEY_F6        = $F015;
  KEY_F7        = $F016;
  KEY_F8        = $F017;
  KEY_F9        = $F018;
  KEY_F10       = $F019;
  KEY_F11       = $F01A;
  KEY_F12       = $F01B;

// ── Box-character constants ─────────────────────────────────────────────────
const
  // Double-line
  BOX_D_TL  = #$2554;  // ╔
  BOX_D_TR  = #$2557;  // ╗
  BOX_D_BL  = #$255A;  // ╚
  BOX_D_BR  = #$255D;  // ╝
  BOX_D_H   = #$2550;  // ═
  BOX_D_V   = #$2551;  // ║
  BOX_D_TL2 = #$2560;  // ╠
  BOX_D_TR2 = #$2563;  // ╣
  BOX_D_TT  = #$2566;  // ╦
  BOX_D_TB  = #$2569;  // ╩
  BOX_D_X   = #$256C;  // ╬

  // Single-line
  BOX_S_TL  = #$250C;  // ┌
  BOX_S_TR  = #$2510;  // ┐
  BOX_S_BL  = #$2514;  // └
  BOX_S_BR  = #$2518;  // ┘
  BOX_S_H   = #$2500;  // ─
  BOX_S_V   = #$2502;  // │
  BOX_S_TL2 = #$251C;  // ├
  BOX_S_TR2 = #$2524;  // ┤
  BOX_S_TT  = #$252C;  // ┬
  BOX_S_TB  = #$2534;  // ┴
  BOX_S_X   = #$253C;  // ┼

  ESC = #27;

  // ANSI SGR foreground colour codes
  FG_CODES: array[TConsoleColor] of string = (
    '0',     // ccDefault
    '30',    // ccBlack
    '31',    // ccRed
    '32',    // ccGreen
    '33',    // ccYellow
    '34',    // ccBlue
    '35',    // ccMagenta
    '36',    // ccCyan
    '37',    // ccWhite
    '90',    // ccGray
    '91',    // ccBrightRed
    '92',    // ccBrightGreen
    '93',    // ccBrightYellow
    '94',    // ccBrightBlue
    '95',    // ccBrightMagenta
    '96',    // ccBrightCyan
    '97'     // ccBrightWhite
  );

implementation

{ ═══════════════════════════════════════════════════════════════════════════
  TConsoleLayout
  ═══════════════════════════════════════════════════════════════════════════ }

constructor TConsoleLayout.Create(AConsole: TConsoleBase; AStyle: TBoxStyle);
begin
  inherited Create;
  FConsole  := AConsole;
  FBoxStyle := AStyle;
end;

{ ═══════════════════════════════════════════════════════════════════════════
  TConsoleBase
  ═══════════════════════════════════════════════════════════════════════════ }

constructor TConsoleBase.Create;
begin
  inherited Create;
  FInitialised := False;
  FLayout := nil;
  FWidth  := 80;
  FHeight := 24;
end;

destructor TConsoleBase.Destroy;
begin
  if FInitialised then
    Shutdown;
  FLayout.Free;
  inherited;
end;

// ── Lifecycle ───────────────────────────────────────────────────────────────

procedure TConsoleBase.Init;
begin
  if FInitialised then Exit;
  PlatformInit;
  PlatformDetectSize;
  FInitialised := True;
end;

procedure TConsoleBase.Shutdown;
begin
  if not FInitialised then Exit;
  ResetColor;
  ShowCursor;
  PlatformShutdown;
  FInitialised := False;
end;

// ── Layout ──────────────────────────────────────────────────────────────────

procedure TConsoleBase.SetLayout(ALayout: TConsoleLayout);
begin
  if FLayout <> ALayout then
  begin
    FLayout.Free;
    FLayout := ALayout;
  end;
  if Assigned(FLayout) then
  begin
    Clear;
    FLayout.DrawFrame;
  end;
end;

procedure TConsoleBase.ClearContent;
var
  CCol, CRow, CW, CH, R: Integer;
begin
  if not Assigned(FLayout) then Exit;
  FLayout.GetContentArea(CCol, CRow, CW, CH);
  for R := CRow to CRow + CH - 1 do
    PrintAt(CCol, R, StringOfChar(' ', CW));
end;

procedure TConsoleBase.ClearInput;
var
  CCol, CRow, CW, CH: Integer;
begin
  if not Assigned(FLayout) then Exit;
  FLayout.GetContentArea(CCol, CRow, CW, CH);
  PrintAt(FLayout.GetInputCol, FLayout.GetInputRow, StringOfChar(' ', CW));
end;

procedure TConsoleBase.PrintContent(ACol, ARow: Integer; const AText: string);
var
  CCol, CRow, CW, CH: Integer;
begin
  if not Assigned(FLayout) then Exit;
  FLayout.GetContentArea(CCol, CRow, CW, CH);
  PrintAt(CCol + ACol - 1, CRow + ARow - 1, AText);
end;

procedure TConsoleBase.ShowStatus(const AText: string);
begin
  ClearInput;
  SetColor(ccGray);
  PrintAt(FLayout.GetInputCol, FLayout.GetInputRow, AText);
  ResetColor;
end;

function TConsoleBase.PromptInput(const APrompt: string; out AExitKey: Word): string;
begin
  ClearInput;
  PrintAt(FLayout.GetInputCol, FLayout.GetInputRow, APrompt);
  SetColor(ccBrightGreen);
  Result := ReadLine(AExitKey);
  ResetColor;
end;

function TConsoleBase.PromptInput(const APrompt: string): string;
var
  Dummy: Word;
begin
  Result := PromptInput(APrompt, Dummy);
end;

// ── Screen ──────────────────────────────────────────────────────────────────

procedure TConsoleBase.Clear;
begin
  System.Write(ESC + '[2J' + ESC + '[H');
end;

procedure TConsoleBase.MoveTo(ACol, ARow: Integer);
begin
  System.Write(Format(ESC + '[%d;%dH', [ARow, ACol]));
end;

procedure TConsoleBase.HideCursor;
begin
  System.Write(ESC + '[?25l');
end;

procedure TConsoleBase.ShowCursor;
begin
  System.Write(ESC + '[?25h');
end;

function TConsoleBase.Width: Integer;
begin
  Result := FWidth;
end;

function TConsoleBase.Height: Integer;
begin
  Result := FHeight;
end;

procedure TConsoleBase.RefreshSize;
begin
  PlatformDetectSize;
end;

// ── Output ──────────────────────────────────────────────────────────────────

procedure TConsoleBase.SetColor(AFg: TConsoleColor);
begin
  System.Write(ESC + '[' + FG_CODES[AFg] + 'm');
end;

procedure TConsoleBase.ResetColor;
begin
  System.Write(ESC + '[0m');
end;

procedure TConsoleBase.Print(const AText: string);
begin
  System.Write(AText);
end;

procedure TConsoleBase.PrintLn(const AText: string);
begin
  System.Write(AText + #13#10);
end;

procedure TConsoleBase.PrintAt(ACol, ARow: Integer; const AText: string);
begin
  MoveTo(ACol, ARow);
  System.Write(AText);
end;

// ── Box drawing ─────────────────────────────────────────────────────────────

class function TConsoleBase.BoxChars(AStyle: TBoxStyle): TBoxChars;
begin
  case AStyle of
    bsSingle:
    begin
      Result.TopLeft     := BOX_S_TL;
      Result.TopRight    := BOX_S_TR;
      Result.BottomLeft  := BOX_S_BL;
      Result.BottomRight := BOX_S_BR;
      Result.Horizontal  := BOX_S_H;
      Result.Vertical    := BOX_S_V;
      Result.TeeLeft     := BOX_S_TR2;
      Result.TeeRight    := BOX_S_TL2;
      Result.TeeTop      := BOX_S_TB;
      Result.TeeBottom   := BOX_S_TT;
      Result.Cross       := BOX_S_X;
    end;
    bsDouble:
    begin
      Result.TopLeft     := BOX_D_TL;
      Result.TopRight    := BOX_D_TR;
      Result.BottomLeft  := BOX_D_BL;
      Result.BottomRight := BOX_D_BR;
      Result.Horizontal  := BOX_D_H;
      Result.Vertical    := BOX_D_V;
      Result.TeeLeft     := BOX_D_TR2;
      Result.TeeRight    := BOX_D_TL2;
      Result.TeeTop      := BOX_D_TB;
      Result.TeeBottom   := BOX_D_TT;
      Result.Cross       := BOX_D_X;
    end;
  end;
end;

procedure TConsoleBase.DrawBox(ALeft, ATop, AWidth, AHeight: Integer;
  AStyle: TBoxStyle);
var
  B: TBoxChars;
  Row: Integer;
  HBar: string;
begin
  B := BoxChars(AStyle);
  HBar := StringOfChar(B.Horizontal, AWidth - 2);

  PrintAt(ALeft, ATop, B.TopLeft + HBar + B.TopRight);

  for Row := ATop + 1 to ATop + AHeight - 2 do
  begin
    PrintAt(ALeft, Row, B.Vertical);
    PrintAt(ALeft + AWidth - 1, Row, B.Vertical);
  end;

  PrintAt(ALeft, ATop + AHeight - 1, B.BottomLeft + HBar + B.BottomRight);
end;

procedure TConsoleBase.DrawHLine(ALeft, ARight, ARow: Integer;
  AStyle: TBoxStyle);
var
  B: TBoxChars;
begin
  B := BoxChars(AStyle);
  PrintAt(ALeft, ARow, B.TeeRight +
    StringOfChar(B.Horizontal, ARight - ALeft - 1) + B.TeeLeft);
end;

// ── Input ───────────────────────────────────────────────────────────────────

function TConsoleBase.ReadKeyCode: Word;
begin
  Result := PlatformReadKeyCode;
end;

function TConsoleBase.ReadKey: Char;
var
  Code: Word;
begin
  // Block until we get a printable character
  repeat
    Code := PlatformReadKeyCode;
  until Code < $F000;  // Filter out extended key codes
  Result := Char(Code);
end;

function TConsoleBase.ReadLine: string;
var
  Dummy: Word;
begin
  Result := ReadLine(Dummy);
end;

function TConsoleBase.ReadLine(out AExitKey: Word): string;
var
  Code: Word;
begin
  Result := '';
  AExitKey := KEY_ENTER;
  repeat
    Code := ReadKeyCode;
    case Code of
      KEY_ENTER:
      begin
        AExitKey := KEY_ENTER;
        Exit;
      end;
      KEY_ESCAPE:
      begin
        AExitKey := KEY_ESCAPE;
        Exit;
      end;
      KEY_BACKSPACE, $007F:
      begin
        if Length(Result) > 0 then
        begin
          Delete(Result, Length(Result), 1);
          Print(#8' '#8);
        end;
      end;
    else
      if Code >= $F000 then
      begin
        // Extended key (arrow, F-key, etc.) — exit and pass it back
        AExitKey := Code;
        Exit;
      end
      else if Code >= Ord(' ') then
      begin
        Result := Result + Char(Code);
        Print(Char(Code));
      end;
    end;
  until False;
end;

function TConsoleBase.KeyPressed: Boolean;
begin
  Result := PlatformKeyPressed;
end;

// ── Menu ────────────────────────────────────────────────────────────────────

function TConsoleBase.ShowMenu(ALeft, ATop: Integer; const ATitle: string;
  const AItems: array of TMenuItem; AStyle: TBoxStyle): Integer;
var
  I: Integer;
  MaxLen: Integer;
  BoxW, BoxH: Integer;
  Code: Word;
  Ch: Char;
begin
  MaxLen := Length(ATitle);
  for I := 0 to High(AItems) do
    if Length(AItems[I].Label_) + 4 > MaxLen then
      MaxLen := Length(AItems[I].Label_) + 4;

  BoxW := MaxLen + 4;
  BoxH := High(AItems) + 5;

  DrawBox(ALeft, ATop, BoxW, BoxH, AStyle);

  SetColor(ccBrightWhite);
  PrintAt(ALeft + 2, ATop + 1, ATitle);

  DrawHLine(ALeft, ALeft + BoxW - 1, ATop + 2, AStyle);

  for I := 0 to High(AItems) do
  begin
    SetColor(ccBrightCyan);
    PrintAt(ALeft + 2, ATop + 3 + I, AItems[I].Key + '. ');
    SetColor(ccWhite);
    Print(AItems[I].Label_);
  end;

  ResetColor;

  repeat
    Code := ReadKeyCode;
    if Code = KEY_ESCAPE then
      Exit(-1);
    if Code < $F000 then
    begin
      Ch := Char(Code);
      for I := 0 to High(AItems) do
        if UpCase(Ch) = UpCase(AItems[I].Key) then
          Exit(I);
    end;
  until False;
end;

end.
