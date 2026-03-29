unit AR.Console.Layouts;

{******************************************************************************
  AR.Console.Layouts — Concrete layout implementations and registry

  Base items:
    TClickableItem       — shared ancestor for anything the user can click
                           or select (bar items, list-box items)

  Concrete layouts:
    TFrameLayout         — shared geometry for framed layouts (title,
                           content, input row).  Not registered directly.
    TSingleFrameLayout   — single-line Unicode frame (┌─┐)
    TDoubleFrameLayout   — double-line Unicode frame (╔═╗)
    TTabBar              — arrow-navigable tab strip with focus state
    TListBox             — scrollable, keyboard/mouse-navigable item list
                           with optional multi-column display
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

  // ── Clickable item base ────────────────────────────────────────────────
  //   Shared ancestor for anything the user can click or select:
  //   bar items (tabs, buttons) and list-box items.
  TItemClickProc = reference to procedure;

  TClickableItem = class
  strict private
    FLabel: string;
    FOnClick: TItemClickProc;
  public
    constructor Create(const ALabel: string; AOnClick: TItemClickProc = nil);
    property Label_: string read FLabel;
    property OnClick: TItemClickProc read FOnClick write FOnClick;
  end;

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
  TBarItemClickProc = TItemClickProc;   // back-compat alias

  TBarItem = class(TClickableItem)
  public
    procedure Draw(AConsole: TConsoleBase; AActive, AFocused: Boolean;
      AActiveColor, AInactiveColor: TConsoleColor); virtual; abstract;
    function DisplayWidth: Integer; virtual; abstract;
  end;

  TTabItem = class(TBarItem)
  public
    procedure Draw(AConsole: TConsoleBase; AActive, AFocused: Boolean;
      AActiveColor, AInactiveColor: TConsoleColor); override;
    function DisplayWidth: Integer; override;
  end;

  TButtonItem = class(TBarItem)
  public
    constructor Create(const ALabel: string; AOnClick: TItemClickProc);
    procedure Draw(AConsole: TConsoleBase; AActive, AFocused: Boolean;
      AActiveColor, AInactiveColor: TConsoleColor); override;
    function DisplayWidth: Integer; override;
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
    function  AddButton(const ALabel: string; AOnClick: TItemClickProc): TButtonItem;
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

  // ── List box component ──────────────────────────────────────────────────
  //   Vertical (or multi-column) list of selectable items.
  //   Keyboard: Up/Down move selection, Left/Right when Columns>1,
  //             PgUp/PgDn scroll by page, Enter fires OnClick.
  //   Mouse:    click selects + fires OnClick, wheel scrolls.
  TListBox = class
  strict private
    FConsole: TConsoleBase;
    FItems: TArray<TClickableItem>;
    FSelectedIndex: Integer;
    FTopIndex: Integer;          // first visible *row* (not item)
    FLeft, FTop, FWidth, FHeight: Integer;
    FColumns: Integer;
    FActiveColor: TConsoleColor;
    FInactiveColor: TConsoleColor;
    FOwnsItems: Boolean;
    function GetItemCount: Integer;
    function GetItem(AIndex: Integer): TClickableItem;
    function RowCount: Integer;
    function VisibleRows: Integer;
    procedure EnsureVisible;
  public
    constructor Create(AConsole: TConsoleBase);
    destructor Destroy; override;
    procedure SetBounds(ALeft, ATop, AWidth, AHeight: Integer);
    function  AddItem(const ALabel: string;
                      AOnClick: TItemClickProc = nil): TClickableItem;
    procedure SetItems(const ALabels: array of string);
    procedure Clear;
    procedure Draw;
    // Returns True if the key was consumed.
    function  HandleKey(AKeyCode: Word): Boolean;
    // Returns item index at screen position, or -1.
    function  HitTest(ACol, ARow: Integer): Integer;
    property  SelectedIndex: Integer read FSelectedIndex write FSelectedIndex;
    property  TopIndex: Integer read FTopIndex;
    property  ItemCount: Integer read GetItemCount;
    property  Items[AIndex: Integer]: TClickableItem read GetItem;
    property  Columns: Integer read FColumns write FColumns;
    property  ActiveColor: TConsoleColor read FActiveColor write FActiveColor;
    property  InactiveColor: TConsoleColor read FInactiveColor write FInactiveColor;
    property  OwnsItems: Boolean read FOwnsItems write FOwnsItems;
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
  TClickableItem
  ═══════════════════════════════════════════════════════════════════════════ }

constructor TClickableItem.Create(const ALabel: string; AOnClick: TItemClickProc);
begin
  inherited Create;
  FLabel   := ALabel;
  FOnClick := AOnClick;
end;

{ ═══════════════════════════════════════════════════════════════════════════
  TBarItem / TTabItem / TButtonItem
  ═══════════════════════════════════════════════════════════════════════════ }

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

constructor TButtonItem.Create(const ALabel: string; AOnClick: TItemClickProc);
begin
  inherited Create(ALabel, AOnClick);
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
  TListBox
  ═══════════════════════════════════════════════════════════════════════════ }

constructor TListBox.Create(AConsole: TConsoleBase);
begin
  inherited Create;
  FConsole       := AConsole;
  FSelectedIndex := 0;
  FTopIndex      := 0;
  FLeft          := 1;
  FTop           := 1;
  FWidth         := 20;
  FHeight        := 10;
  FColumns       := 1;
  FActiveColor   := ccBrightWhite;
  FInactiveColor := ccGray;
  FOwnsItems     := True;
end;

destructor TListBox.Destroy;
begin
  if FOwnsItems then
    Clear;
  inherited;
end;

procedure TListBox.SetBounds(ALeft, ATop, AWidth, AHeight: Integer);
begin
  FLeft   := ALeft;
  FTop    := ATop;
  FWidth  := AWidth;
  FHeight := AHeight;
end;

function TListBox.GetItemCount: Integer;
begin
  Result := Length(FItems);
end;

function TListBox.GetItem(AIndex: Integer): TClickableItem;
begin
  Result := FItems[AIndex];
end;

function TListBox.RowCount: Integer;
begin
  Result := (Length(FItems) + FColumns - 1) div FColumns;
end;

function TListBox.VisibleRows: Integer;
begin
  Result := FHeight;
end;

procedure TListBox.EnsureVisible;
var
  SelRow: Integer;
begin
  if Length(FItems) = 0 then Exit;
  SelRow := FSelectedIndex div FColumns;
  if SelRow < FTopIndex then
    FTopIndex := SelRow
  else if SelRow >= FTopIndex + VisibleRows then
    FTopIndex := SelRow - VisibleRows + 1;
end;

function TListBox.AddItem(const ALabel: string;
  AOnClick: TItemClickProc): TClickableItem;
begin
  Result := TClickableItem.Create(ALabel, AOnClick);
  SetLength(FItems, Length(FItems) + 1);
  FItems[High(FItems)] := Result;
end;

procedure TListBox.SetItems(const ALabels: array of string);
var
  I: Integer;
begin
  Clear;
  SetLength(FItems, Length(ALabels));
  for I := 0 to High(ALabels) do
    FItems[I] := TClickableItem.Create(ALabels[I]);
  FSelectedIndex := 0;
  FTopIndex := 0;
end;

procedure TListBox.Clear;
var
  I: Integer;
begin
  if FOwnsItems then
    for I := 0 to High(FItems) do
      FItems[I].Free;
  FItems := nil;
  FSelectedIndex := 0;
  FTopIndex := 0;
end;

procedure TListBox.Draw;
var
  R, C, Idx: Integer;
  ColW: Integer;
  Lbl: string;
  ScreenRow: Integer;
begin
  if FColumns < 1 then FColumns := 1;
  ColW := FWidth div FColumns;

  for R := FTopIndex to FTopIndex + VisibleRows - 1 do
  begin
    ScreenRow := FTop + (R - FTopIndex);
    // Clear the whole row first
    FConsole.PrintAt(FLeft, ScreenRow, StringOfChar(' ', FWidth));

    for C := 0 to FColumns - 1 do
    begin
      Idx := R * FColumns + C;
      if Idx > High(FItems) then
        Break;

      Lbl := FItems[Idx].Label_;
      // Truncate if too wide
      if Length(Lbl) > ColW - 2 then
        Lbl := Copy(Lbl, 1, ColW - 3) + #$2026;  // ellipsis
      Lbl := ' ' + Lbl + StringOfChar(' ', ColW - Length(Lbl) - 1);
      // Clamp to column width
      if Length(Lbl) > ColW then
        Lbl := Copy(Lbl, 1, ColW);

      FConsole.MoveTo(FLeft + C * ColW, ScreenRow);

      if Idx = FSelectedIndex then
      begin
        FConsole.SetColor(FActiveColor);
        System.Write(ESC + '[7m');   // reverse video
        FConsole.Print(Lbl);
        System.Write(ESC + '[27m');
      end
      else
      begin
        FConsole.SetColor(FInactiveColor);
        FConsole.Print(Lbl);
      end;
    end;
  end;

  FConsole.ResetColor;
end;

function TListBox.HandleKey(AKeyCode: Word): Boolean;
var
  PageSize, NewIdx: Integer;
begin
  Result := True;
  if Length(FItems) = 0 then
    Exit(False);

  case AKeyCode of
    KEY_UP:
    begin
      NewIdx := FSelectedIndex - FColumns;
      if NewIdx >= 0 then
      begin
        FSelectedIndex := NewIdx;
        EnsureVisible;
        Draw;
      end;
    end;
    KEY_DOWN:
    begin
      NewIdx := FSelectedIndex + FColumns;
      if NewIdx <= High(FItems) then
      begin
        FSelectedIndex := NewIdx;
        EnsureVisible;
        Draw;
      end;
    end;
    KEY_LEFT:
    begin
      if (FColumns > 1) and (FSelectedIndex mod FColumns > 0) then
      begin
        Dec(FSelectedIndex);
        Draw;
      end
      else
        Result := False;
    end;
    KEY_RIGHT:
    begin
      if (FColumns > 1) and (FSelectedIndex mod FColumns < FColumns - 1)
        and (FSelectedIndex + 1 <= High(FItems)) then
      begin
        Inc(FSelectedIndex);
        Draw;
      end
      else
        Result := False;
    end;
    KEY_PGUP:
    begin
      PageSize := VisibleRows * FColumns;
      FSelectedIndex := FSelectedIndex - PageSize;
      if FSelectedIndex < 0 then
        FSelectedIndex := 0;
      EnsureVisible;
      Draw;
    end;
    KEY_PGDN:
    begin
      PageSize := VisibleRows * FColumns;
      FSelectedIndex := FSelectedIndex + PageSize;
      if FSelectedIndex > High(FItems) then
        FSelectedIndex := High(FItems);
      EnsureVisible;
      Draw;
    end;
    KEY_HOME:
    begin
      FSelectedIndex := 0;
      EnsureVisible;
      Draw;
    end;
    KEY_END_:
    begin
      FSelectedIndex := High(FItems);
      EnsureVisible;
      Draw;
    end;
    KEY_ENTER:
    begin
      if Assigned(FItems[FSelectedIndex].OnClick) then
        FItems[FSelectedIndex].OnClick();
    end;
  else
    Result := False;
  end;
end;

function TListBox.HitTest(ACol, ARow: Integer): Integer;
var
  RelRow, RelCol, ColW, C, R, Idx: Integer;
begin
  Result := -1;
  if (ARow < FTop) or (ARow >= FTop + VisibleRows) then Exit;
  if (ACol < FLeft) or (ACol >= FLeft + FWidth) then Exit;

  RelRow := ARow - FTop;
  RelCol := ACol - FLeft;
  ColW := FWidth div FColumns;
  C := RelCol div ColW;
  R := FTopIndex + RelRow;
  Idx := R * FColumns + C;

  if (Idx >= 0) and (Idx <= High(FItems)) then
    Result := Idx;
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
