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

  // ── Bar item base class ────────────────────────────────────────────────
  //   A clickable element in the tab bar.  Subclasses decide appearance.
  TBarItemClickProc = reference to procedure;

  TBarItem = class
  private
    FLabel: string;
  public
    constructor Create(const ALabel: string);
    procedure Draw(AConsole: TConsoleBase; AActive, AFocused: Boolean;
      AActiveColor, AInactiveColor: TConsoleColor); virtual; abstract;
    function DisplayWidth: Integer; virtual; abstract;
    property Label_: string read FLabel;
  end;

  TTabItem = class(TBarItem)
  public
    procedure Draw(AConsole: TConsoleBase; AActive, AFocused: Boolean;
      AActiveColor, AInactiveColor: TConsoleColor); override;
    function DisplayWidth: Integer; override;
  end;

  TButtonItem = class(TBarItem)
  private
    FOnClick: TBarItemClickProc;
  public
    constructor Create(const ALabel: string; AOnClick: TBarItemClickProc);
    procedure Draw(AConsole: TConsoleBase; AActive, AFocused: Boolean;
      AActiveColor, AInactiveColor: TConsoleColor); override;
    function DisplayWidth: Integer; override;
    property OnClick: TBarItemClickProc read FOnClick;
  end;

  // ── Tab bar component ───────────────────────────────────────────────────
  TTabBar = class
  private
    FConsole: TConsoleBase;
    FItems: TArray<TBarItem>;
    FActiveIndex: Integer;
    FRow: Integer;
    FLeft: Integer;
    FWidth: Integer;
    FActiveColor: TConsoleColor;
    FInactiveColor: TConsoleColor;
    FFocused: Boolean;
    procedure ClearItems;
    function GetItem(AIndex: Integer): TBarItem;
  public
    constructor Create(AConsole: TConsoleBase);
    destructor Destroy; override;
    procedure SetTabs(const ATabs: array of string);
    function  AddButton(const ALabel: string; AOnClick: TBarItemClickProc): TButtonItem;
    procedure SetBounds(ALeft, ARow, AWidth: Integer);
    procedure Draw;
    procedure SelectNext;
    procedure SelectPrev;
    procedure SelectTab(AIndex: Integer);
    function  TabCount: Integer;
    function  ItemCount: Integer;
    function  IsButton(AIndex: Integer): Boolean;
    // Returns the item index at screen position (ACol, ARow), or -1 if none.
    function  HitTest(ACol, ARow: Integer): Integer;
    property  Items[AIndex: Integer]: TBarItem read GetItem;
    property  ActiveIndex: Integer read FActiveIndex;
    property  ActiveColor: TConsoleColor read FActiveColor write FActiveColor;
    property  InactiveColor: TConsoleColor read FInactiveColor write FInactiveColor;
    property  Focused: Boolean read FFocused write FFocused;
    property  Row: Integer read FRow;
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
  TBarItem / TTabItem / TButtonItem
  ═══════════════════════════════════════════════════════════════════════════ }

constructor TBarItem.Create(const ALabel: string);
begin
  inherited Create;
  FLabel := ALabel;
end;

// ── TTabItem ──────────────────────────────────────────────────────────────

function TTabItem.DisplayWidth: Integer;
begin
  Result := Length(Label_) + 2;  // ' Label '
end;

procedure TTabItem.Draw(AConsole: TConsoleBase; AActive, AFocused: Boolean;
  AActiveColor, AInactiveColor: TConsoleColor);
var
  Lbl: string;
begin
  Lbl := ' ' + Label_ + ' ';
  if AActive then
  begin
    if AFocused then
    begin
      AConsole.SetColor(AActiveColor);
      System.Write(ESC + '[7m');
      AConsole.Print(Lbl);
      System.Write(ESC + '[27m');
    end
    else
    begin
      AConsole.SetColor(ccCyan);
      System.Write(ESC + '[4m');
      AConsole.Print(Lbl);
      System.Write(ESC + '[24m');
    end;
  end
  else
  begin
    AConsole.SetColor(AInactiveColor);
    AConsole.Print(Lbl);
  end;
end;

// ── TButtonItem ───────────────────────────────────────────────────────────

constructor TButtonItem.Create(const ALabel: string; AOnClick: TBarItemClickProc);
begin
  inherited Create(ALabel);
  FOnClick := AOnClick;
end;

function TButtonItem.DisplayWidth: Integer;
begin
  Result := Length(Label_) + 4;  // '[ Label ]'
end;

procedure TButtonItem.Draw(AConsole: TConsoleBase; AActive, AFocused: Boolean;
  AActiveColor, AInactiveColor: TConsoleColor);
var
  Lbl: string;
begin
  Lbl := '[ ' + Label_ + ' ]';
  AConsole.SetColor(ccBrightCyan);
  AConsole.Print(Lbl);
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

destructor TTabBar.Destroy;
begin
  ClearItems;
  inherited;
end;

procedure TTabBar.ClearItems;
var
  I: Integer;
begin
  for I := 0 to High(FItems) do
    FItems[I].Free;
  FItems := nil;
end;

function TTabBar.GetItem(AIndex: Integer): TBarItem;
begin
  Result := FItems[AIndex];
end;

procedure TTabBar.SetTabs(const ATabs: array of string);
var
  I: Integer;
begin
  ClearItems;
  SetLength(FItems, Length(ATabs));
  for I := 0 to High(ATabs) do
    FItems[I] := TTabItem.Create(ATabs[I]);
  if FActiveIndex >= Length(FItems) then
    FActiveIndex := 0;
end;

function TTabBar.AddButton(const ALabel: string;
  AOnClick: TBarItemClickProc): TButtonItem;
begin
  Result := TButtonItem.Create(ALabel, AOnClick);
  SetLength(FItems, Length(FItems) + 1);
  FItems[High(FItems)] := Result;
end;

procedure TTabBar.SetBounds(ALeft, ARow, AWidth: Integer);
begin
  FLeft  := ALeft;
  FRow   := ARow;
  FWidth := AWidth;
end;

procedure TTabBar.Draw;
var
  I, Col: Integer;
begin
  FConsole.PrintAt(FLeft, FRow, StringOfChar(' ', FWidth));

  Col := FLeft;
  for I := 0 to High(FItems) do
  begin
    FConsole.MoveTo(Col, FRow);
    FItems[I].Draw(FConsole, I = FActiveIndex, FFocused,
                   FActiveColor, FInactiveColor);
    Col := Col + FItems[I].DisplayWidth + 1;
  end;

  FConsole.ResetColor;
end;

procedure TTabBar.SelectNext;
var
  Start, I: Integer;
begin
  if Length(FItems) = 0 then Exit;
  Start := FActiveIndex;
  I := FActiveIndex;
  repeat
    I := (I + 1) mod Length(FItems);
    if FItems[I] is TTabItem then
    begin
      FActiveIndex := I;
      Draw;
      Exit;
    end;
  until I = Start;
end;

procedure TTabBar.SelectPrev;
var
  Start, I: Integer;
begin
  if Length(FItems) = 0 then Exit;
  Start := FActiveIndex;
  I := FActiveIndex;
  repeat
    I := (I - 1 + Length(FItems)) mod Length(FItems);
    if FItems[I] is TTabItem then
    begin
      FActiveIndex := I;
      Draw;
      Exit;
    end;
  until I = Start;
end;

procedure TTabBar.SelectTab(AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex <= High(FItems))
    and (FItems[AIndex] is TTabItem) then
  begin
    FActiveIndex := AIndex;
    Draw;
  end;
end;

function TTabBar.TabCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FItems) do
    if FItems[I] is TTabItem then
      Inc(Result);
end;

function TTabBar.ItemCount: Integer;
begin
  Result := Length(FItems);
end;

function TTabBar.IsButton(AIndex: Integer): Boolean;
begin
  Result := (AIndex >= 0) and (AIndex <= High(FItems))
    and (FItems[AIndex] is TButtonItem);
end;

function TTabBar.HitTest(ACol, ARow: Integer): Integer;
var
  I, Col, NextCol: Integer;
begin
  Result := -1;
  // Accept clicks on the tab row and the divider rows directly above/below
  if (ARow < FRow - 1) or (ARow > FRow + 1) then Exit;
  if (ACol < FLeft) or (ACol >= FLeft + FWidth) then Exit;

  Col := FLeft;
  for I := 0 to High(FItems) do
  begin
    // Each item owns the space up to the next item's start,
    // or to the end of the bar for the last item.
    if I < High(FItems) then
      NextCol := Col + FItems[I].DisplayWidth + 1
    else
      NextCol := FLeft + FWidth;
    if (ACol >= Col) and (ACol < NextCol) then
      Exit(I);
    Col := NextCol;
  end;
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
