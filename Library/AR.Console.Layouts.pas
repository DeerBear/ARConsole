unit AR.Console.Layouts;

{******************************************************************************
  AR.Console.Layouts — Concrete layout implementations and registry

  Concrete layouts:
    TFrameLayout         — shared geometry for framed layouts (title,
                           content, input row).  Not registered directly.
    TSingleFrameLayout   — single-line Unicode frame (┌─┐)
    TDoubleFrameLayout   — double-line Unicode frame (╔═╗)
    TTabBar              — arrow-navigable tab strip with focus state
    TTabbedLayout        — framed layout with an embedded tab bar

  Registry:
    TLayoutRegistry      — class-level registry of named layout classes.
                           Enumerate with Count/GetName, instantiate with
                           CreateLayout.  Frame layouts self-register in
                           the initialization section.

  (c) 2024 - Signal-Based LLM POC
******************************************************************************}

interface

uses
  System.SysUtils, System.Classes,
  AR.Console.Base;

type
  TConsoleLayoutClass = class of TConsoleLayout;

  // ── Shared frame geometry ───────────────────────────────────────────────
  //
  //   ╔══════════════════════════════════╗   ┌──────────────────────────────────┐
  //   ║  Title                           ║   │  Title                           │
  //   ╠══════════════════════════════════╣   ├──────────────────────────────────┤
  //   ║                                  ║   │                                  │
  //   ║  (content area)                  ║   │  (content area)                  │
  //   ║                                  ║   │                                  │
  //   ╠══════════════════════════════════╣   ├──────────────────────────────────┤
  //   ║ > _                              ║   │ > _                              │
  //   ╚══════════════════════════════════╝   └──────────────────────────────────┘
  //
  TFrameLayout = class(TConsoleLayout)
  public
    procedure DrawFrame; override;
    procedure DrawPreview(ALeft, ATop, AWidth, AHeight: Integer); override;
    procedure GetContentArea(out ACol, ARow, AWidth, AHeight: Integer); override;
    function  GetInputRow: Integer; override;
    function  GetInputCol: Integer; override;
    procedure GetTitleArea(out ACol, ARow, AWidth: Integer); override;
  end;

  TSingleFrameLayout = class(TFrameLayout)
  public
    constructor Create(AConsole: TConsoleBase; AStyle: TBoxStyle = bsSingle); override;
  end;

  TDoubleFrameLayout = class(TFrameLayout)
  public
    constructor Create(AConsole: TConsoleBase; AStyle: TBoxStyle = bsDouble); override;
  end;

  // ── Tab bar component ───────────────────────────────────────────────────
  TTabBar = class
  private
    FConsole: TConsoleBase;
    FTabs: TArray<string>;
    FActiveIndex: Integer;
    FRow: Integer;
    FLeft: Integer;
    FWidth: Integer;
    FActiveColor: TConsoleColor;
    FInactiveColor: TConsoleColor;
    FFocused: Boolean;
  public
    constructor Create(AConsole: TConsoleBase);
    procedure SetTabs(const ATabs: array of string);
    procedure SetBounds(ALeft, ARow, AWidth: Integer);
    procedure Draw;
    procedure SelectNext;
    procedure SelectPrev;
    procedure SelectTab(AIndex: Integer);
    function  TabCount: Integer;
    property  ActiveIndex: Integer read FActiveIndex;
    property  ActiveColor: TConsoleColor read FActiveColor write FActiveColor;
    property  InactiveColor: TConsoleColor read FInactiveColor write FInactiveColor;
    property  Focused: Boolean read FFocused write FFocused;
  end;

  // ── Tabbed layout ──────────────────────────────────────────────────────
  //
  //   ╔══════════════════════════════════╗
  //   ║  Title                           ║
  //   ╠══════════════════════════════════╣
  //   ║  [Tab1]  Tab2   Tab3             ║
  //   ╠══════════════════════════════════╣
  //   ║                                  ║
  //   ║  (content area)                  ║
  //   ║                                  ║
  //   ╠══════════════════════════════════╣
  //   ║ > _                              ║
  //   ╚══════════════════════════════════╝
  //
  TTabbedLayout = class(TConsoleLayout)
  private
    FTabBar: TTabBar;
  public
    constructor Create(AConsole: TConsoleBase; AStyle: TBoxStyle = bsDouble); override;
    destructor Destroy; override;
    procedure DrawFrame; override;
    procedure DrawPreview(ALeft, ATop, AWidth, AHeight: Integer); override;
    procedure GetContentArea(out ACol, ARow, AWidth, AHeight: Integer); override;
    function  GetInputRow: Integer; override;
    function  GetInputCol: Integer; override;
    procedure GetTitleArea(out ACol, ARow, AWidth: Integer); override;
    property  TabBar: TTabBar read FTabBar;
  end;

  // ── Layout registry ────────────────────────────────────────────────────
  TLayoutInfo = record
    Name: string;
    LayoutClass: TConsoleLayoutClass;
  end;

  TLayoutRegistry = class
  private
    class var FLayouts: TArray<TLayoutInfo>;
  public
    class procedure Register(const AName: string; AClass: TConsoleLayoutClass);
    class function Count: Integer;
    class function GetName(AIndex: Integer): string;
    class function GetClass(AIndex: Integer): TConsoleLayoutClass;
    class function CreateLayout(AIndex: Integer; AConsole: TConsoleBase): TConsoleLayout;
  end;

implementation

{ ═══════════════════════════════════════════════════════════════════════════
  TFrameLayout
  ═══════════════════════════════════════════════════════════════════════════ }

procedure TFrameLayout.DrawFrame;
var
  W, H: Integer;
begin
  W := FConsole.Width;
  H := FConsole.Height;

  FConsole.DrawBox(1, 1, W, H, FBoxStyle);
  FConsole.DrawHLine(1, W, 3, FBoxStyle);

  if H > 5 then
    FConsole.DrawHLine(1, W, H - 2, FBoxStyle);
end;

procedure TFrameLayout.GetContentArea(out ACol, ARow, AWidth, AHeight: Integer);
begin
  ACol    := 3;
  ARow    := 4;
  AWidth  := FConsole.Width - 4;
  AHeight := FConsole.Height - 6;
end;

function TFrameLayout.GetInputRow: Integer;
begin
  Result := FConsole.Height - 1;
end;

function TFrameLayout.GetInputCol: Integer;
begin
  Result := 3;
end;

procedure TFrameLayout.GetTitleArea(out ACol, ARow, AWidth: Integer);
begin
  ACol   := 3;
  ARow   := 2;
  AWidth := FConsole.Width - 4;
end;

procedure TFrameLayout.DrawPreview(ALeft, ATop, AWidth, AHeight: Integer);
var
  B: TBoxChars;
  Bottom: Integer;
begin
  B := TConsoleBase.BoxChars(FBoxStyle);
  Bottom := ATop + AHeight - 1;

  // Outer frame
  FConsole.SetColor(ccBrightWhite);
  FConsole.DrawBox(ALeft, ATop, AWidth, AHeight, FBoxStyle);

  // Title divider
  FConsole.DrawHLine(ALeft, ALeft + AWidth - 1, ATop + 2, FBoxStyle);

  // Title text
  FConsole.SetColor(ccBrightYellow);
  FConsole.PrintAt(ALeft + 2, ATop + 1, 'Title');

  // Content sample
  FConsole.SetColor(ccGray);
  FConsole.PrintAt(ALeft + 2, ATop + 3, 'Content area');
  if AHeight > 7 then
    FConsole.PrintAt(ALeft + 2, ATop + 4,
      B.TeeRight + B.Horizontal + B.Cross + B.Horizontal + B.TeeLeft +
      ' junctions');

  // Input divider + prompt
  if AHeight > 5 then
  begin
    FConsole.DrawHLine(ALeft, ALeft + AWidth - 1, Bottom - 2, FBoxStyle);
    FConsole.SetColor(ccBrightGreen);
    FConsole.PrintAt(ALeft + 2, Bottom - 1, '> _');
  end;

  FConsole.ResetColor;
end;

{ ═══════════════════════════════════════════════════════════════════════════
  TSingleFrameLayout / TDoubleFrameLayout
  ═══════════════════════════════════════════════════════════════════════════ }

constructor TSingleFrameLayout.Create(AConsole: TConsoleBase; AStyle: TBoxStyle);
begin
  inherited Create(AConsole, bsSingle);
end;

constructor TDoubleFrameLayout.Create(AConsole: TConsoleBase; AStyle: TBoxStyle);
begin
  inherited Create(AConsole, bsDouble);
end;

{ ═══════════════════════════════════════════════════════════════════════════
  TTabBar
  ═══════════════════════════════════════════════════════════════════════════ }

constructor TTabBar.Create(AConsole: TConsoleBase);
begin
  inherited Create;
  FConsole       := AConsole;
  FActiveIndex   := 0;
  FRow           := 1;
  FLeft          := 3;
  FWidth         := 76;
  FActiveColor   := ccBrightWhite;
  FInactiveColor := ccGray;
  FFocused       := True;
end;

procedure TTabBar.SetTabs(const ATabs: array of string);
var
  I: Integer;
begin
  SetLength(FTabs, Length(ATabs));
  for I := 0 to High(ATabs) do
    FTabs[I] := ATabs[I];
  if FActiveIndex >= Length(FTabs) then
    FActiveIndex := 0;
end;

procedure TTabBar.SetBounds(ALeft, ARow, AWidth: Integer);
begin
  FLeft  := ALeft;
  FRow   := ARow;
  FWidth := AWidth;
end;

procedure TTabBar.Draw;
var
  I: Integer;
  Col: Integer;
  Lbl: string;
begin
  FConsole.PrintAt(FLeft, FRow, StringOfChar(' ', FWidth));

  Col := FLeft;
  for I := 0 to High(FTabs) do
  begin
    FConsole.MoveTo(Col, FRow);
    Lbl := ' ' + FTabs[I] + ' ';

    if I = FActiveIndex then
    begin
      if FFocused then
      begin
        FConsole.SetColor(FActiveColor);
        System.Write(ESC + '[7m');
        FConsole.Print(Lbl);
        System.Write(ESC + '[27m');
      end
      else
      begin
        FConsole.SetColor(ccCyan);
        System.Write(ESC + '[4m');
        FConsole.Print(Lbl);
        System.Write(ESC + '[24m');
      end;
      FConsole.ResetColor;
    end
    else
    begin
      FConsole.SetColor(FInactiveColor);
      FConsole.Print(Lbl);
    end;

    Col := Col + Length(Lbl) + 1;
  end;

  FConsole.ResetColor;
end;

procedure TTabBar.SelectNext;
begin
  if Length(FTabs) = 0 then Exit;
  FActiveIndex := (FActiveIndex + 1) mod Length(FTabs);
  Draw;
end;

procedure TTabBar.SelectPrev;
begin
  if Length(FTabs) = 0 then Exit;
  FActiveIndex := (FActiveIndex - 1 + Length(FTabs)) mod Length(FTabs);
  Draw;
end;

procedure TTabBar.SelectTab(AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex < Length(FTabs)) then
  begin
    FActiveIndex := AIndex;
    Draw;
  end;
end;

function TTabBar.TabCount: Integer;
begin
  Result := Length(FTabs);
end;

{ ═══════════════════════════════════════════════════════════════════════════
  TTabbedLayout
  ═══════════════════════════════════════════════════════════════════════════ }

constructor TTabbedLayout.Create(AConsole: TConsoleBase; AStyle: TBoxStyle);
begin
  inherited Create(AConsole, AStyle);
  FTabBar := TTabBar.Create(AConsole);
end;

destructor TTabbedLayout.Destroy;
begin
  FTabBar.Free;
  inherited;
end;

procedure TTabbedLayout.DrawFrame;
var
  W, H: Integer;
begin
  W := FConsole.Width;
  H := FConsole.Height;

  FConsole.DrawBox(1, 1, W, H, FBoxStyle);
  FConsole.DrawHLine(1, W, 3, FBoxStyle);

  FTabBar.SetBounds(3, 4, W - 4);
  FConsole.DrawHLine(1, W, 5, FBoxStyle);

  if H > 7 then
    FConsole.DrawHLine(1, W, H - 2, FBoxStyle);

  FTabBar.Draw;
end;

procedure TTabbedLayout.GetContentArea(out ACol, ARow, AWidth, AHeight: Integer);
begin
  ACol    := 3;
  ARow    := 6;
  AWidth  := FConsole.Width - 4;
  AHeight := FConsole.Height - 8;
end;

function TTabbedLayout.GetInputRow: Integer;
begin
  Result := FConsole.Height - 1;
end;

function TTabbedLayout.GetInputCol: Integer;
begin
  Result := 3;
end;

procedure TTabbedLayout.GetTitleArea(out ACol, ARow, AWidth: Integer);
begin
  ACol   := 3;
  ARow   := 2;
  AWidth := FConsole.Width - 4;
end;

procedure TTabbedLayout.DrawPreview(ALeft, ATop, AWidth, AHeight: Integer);
var
  B: TBoxChars;
  Bottom: Integer;
begin
  B := TConsoleBase.BoxChars(FBoxStyle);
  Bottom := ATop + AHeight - 1;

  // Outer frame
  FConsole.SetColor(ccBrightWhite);
  FConsole.DrawBox(ALeft, ATop, AWidth, AHeight, FBoxStyle);

  // Title divider
  FConsole.DrawHLine(ALeft, ALeft + AWidth - 1, ATop + 2, FBoxStyle);

  // Title text
  FConsole.SetColor(ccBrightYellow);
  FConsole.PrintAt(ALeft + 2, ATop + 1, 'Title');

  // Tab bar row + divider
  FConsole.SetColor(ccCyan);
  FConsole.PrintAt(ALeft + 2, ATop + 3, 'Tab1 Tab2 Tab3');
  FConsole.DrawHLine(ALeft, ALeft + AWidth - 1, ATop + 4, FBoxStyle);

  // Content sample
  FConsole.SetColor(ccGray);
  if AHeight > 9 then
  begin
    FConsole.PrintAt(ALeft + 2, ATop + 5, 'Content area');
    FConsole.PrintAt(ALeft + 2, ATop + 6,
      B.TeeRight + B.Horizontal + B.Cross + B.Horizontal + B.TeeLeft +
      ' junctions');
  end;

  // Input divider + prompt
  if AHeight > 7 then
  begin
    FConsole.DrawHLine(ALeft, ALeft + AWidth - 1, Bottom - 2, FBoxStyle);
    FConsole.SetColor(ccBrightGreen);
    FConsole.PrintAt(ALeft + 2, Bottom - 1, '> _');
  end;

  FConsole.ResetColor;
end;

{ ═══════════════════════════════════════════════════════════════════════════
  TLayoutRegistry
  ═══════════════════════════════════════════════════════════════════════════ }

class procedure TLayoutRegistry.Register(const AName: string; AClass: TConsoleLayoutClass);
var
  Info: TLayoutInfo;
begin
  Info.Name := AName;
  Info.LayoutClass := AClass;
  SetLength(FLayouts, Length(FLayouts) + 1);
  FLayouts[High(FLayouts)] := Info;
end;

class function TLayoutRegistry.Count: Integer;
begin
  Result := Length(FLayouts);
end;

class function TLayoutRegistry.GetName(AIndex: Integer): string;
begin
  Result := FLayouts[AIndex].Name;
end;

class function TLayoutRegistry.GetClass(AIndex: Integer): TConsoleLayoutClass;
begin
  Result := FLayouts[AIndex].LayoutClass;
end;

class function TLayoutRegistry.CreateLayout(AIndex: Integer;
  AConsole: TConsoleBase): TConsoleLayout;
begin
  Result := FLayouts[AIndex].LayoutClass.Create(AConsole);
end;

initialization
  TLayoutRegistry.Register('Single Frame', TSingleFrameLayout);
  TLayoutRegistry.Register('Double Frame', TDoubleFrameLayout);

end.
