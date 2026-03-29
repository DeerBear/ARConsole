program ConsoleTest;

{$APPTYPE CONSOLE}

{******************************************************************************
  ConsoleTest — Smoke test for AR.Console

  Tabbed interface demonstrating the TUI framework:

    Tab 1: Colours    — full colour palette
    Tab 2: Input      — line input with echo
    Tab 3: Layouts    — enumerate registered layouts from TLayoutRegistry,
                        preview each with sample box drawing, Enter applies

  Focus model:
    Tab bar focused : Left/Right/Tab cycle tabs, Enter/Down enters content,
                      mouse click on tab switches, scroll wheel scrolls
    Content focused : Tab-specific keys, Tab/Escape returns to tab bar

  Escape from the tab bar exits the application.
******************************************************************************}

uses
  System.SysUtils,
  AR.Console.Base in '..\Library\AR.Console.Base.pas',
  AR.Console.Layouts in '..\Library\AR.Console.Layouts.pas',
  AR.Console in '..\Library\AR.Console.pas',
  AR.Console.POSIX in '..\Library\AR.Console.POSIX.pas',
  AR.Console.Windows in '..\Library\AR.Console.Windows.pas';

const
  HINT_TABBAR  = #$25C4 + '/' + #$25BA + '/Tab switch    Enter go inside    Esc exit';
  HINT_CONTENT = 'Tab/Esc back to tabs';

var
  GLayout: TTabbedLayout;

procedure DrawTitle; forward;

// ═══════════════════════════════════════════════════════════════════════════
//  Tab content handlers
//
//  Each returns the key code that caused it to exit so the main loop
//  can act on it.
// ═══════════════════════════════════════════════════════════════════════════

// ── Colours ─────────────────────────────────────────────────────────────

function RunColoursContent: Word;
const
  COLOR_NAMES: array[TConsoleColor] of string = (
    'Default', 'Black', 'Red', 'Green', 'Yellow', 'Blue',
    'Magenta', 'Cyan', 'White', 'Gray', 'BrightRed', 'BrightGreen',
    'BrightYellow', 'BrightBlue', 'BrightMagenta', 'BrightCyan', 'BrightWhite'
  );
var
  C: TConsoleColor;
  Row: Integer;
  CCol, CRow, CW, CH: Integer;
begin
  Con.ClearContent;

  Con.SetColor(ccBrightWhite);
  Con.PrintContent(1, 1, 'Colour Palette');
  Con.ResetColor;

  GLayout.GetContentArea(CCol, CRow, CW, CH);
  Row := 0;
  for C := Low(TConsoleColor) to High(TConsoleColor) do
  begin
    if Row + 2 >= CH then Break;
    Con.SetColor(C);
    Con.PrintContent(1, 3 + Row, Format('%-16s  Sample text', [COLOR_NAMES[C]]));
    Inc(Row);
  end;
  Con.ResetColor;

  Con.ShowStatus(HINT_CONTENT);

  repeat
    Result := Con.ReadKeyCode;
    case Result of
      KEY_TAB, KEY_ESCAPE:
        Exit;
    end;
  until False;
end;

// ── Input ───────────────────────────────────────────────────────────────

function RunInputContent: Word;
var
  Input: string;
  ExitKey: Word;
begin
  Con.ClearContent;

  Con.SetColor(ccBrightWhite);
  Con.PrintContent(1, 1, 'Line Input Test');
  Con.SetColor(ccGray);
  Con.PrintContent(1, 3, 'Type something and press Enter.');
  Con.PrintContent(1, 4, 'Backspace works. Unicode welcome.');
  Con.PrintContent(1, 5, 'Tab/Esc returns to tab bar.');
  Con.ResetColor;

  Input := Con.PromptInput('> ', ExitKey);

  if ExitKey = KEY_ENTER then
  begin
    Con.SetColor(ccBrightCyan);
    Con.PrintContent(1, 7, 'You typed: ' + Input);
    Con.ResetColor;
    Con.ShowStatus(HINT_CONTENT);

    repeat
      Result := Con.ReadKeyCode;
      case Result of
        KEY_TAB, KEY_ESCAPE:
          Exit;
      end;
    until False;
  end
  else
    Result := ExitKey;
end;

// ── Layouts ─────────────────────────────────────────────────────────────

function RunLayoutsContent: Word;
var
  I, Count: Integer;
  CCol, CRow, CW, CH: Integer;
  PreviewLeft, PreviewW, PreviewH: Integer;
  LB: TListBox;
  ME: TMouseEvent;
  Hit: Integer;

  procedure DrawLayoutPreview;
  var
    R: Integer;
    Tmp: TConsoleLayout;
  begin
    for R := CRow + 2 to CRow + 2 + PreviewH do
      Con.PrintAt(PreviewLeft, R, StringOfChar(' ', PreviewW + 2));

    Tmp := TLayoutRegistry.CreateLayout(LB.SelectedIndex, Con);
    try
      Tmp.DrawPreview(PreviewLeft, CRow + 2, PreviewW, PreviewH);
    finally
      Tmp.Free;
    end;
  end;

  procedure ApplySelected;
  begin
    if TLayoutRegistry.GetClass(LB.SelectedIndex) = TSingleFrameLayout then
      GLayout.BoxStyle := bsSingle
    else
      GLayout.BoxStyle := bsDouble;

    Con.Clear;
    GLayout.DrawFrame;
    DrawTitle;
  end;

begin
  Con.ClearContent;
  GLayout.GetContentArea(CCol, CRow, CW, CH);

  Count := TLayoutRegistry.Count;

  // Preview dimensions
  PreviewLeft := CCol + 24;
  PreviewW := CW - 26;
  if PreviewW > 40 then PreviewW := 40;
  PreviewH := CH - 3;
  if PreviewH > 10 then PreviewH := 10;

  LB := TListBox.Create(Con);
  try
    LB.SetBounds(CCol, CRow + 2, 22, CH - 3);
    for I := 0 to Count - 1 do
      LB.AddItem(TLayoutRegistry.GetName(I));

    // Match current box style to a registered layout
    for I := 0 to Count - 1 do
    begin
      if (TLayoutRegistry.GetClass(I) = TDoubleFrameLayout) and (GLayout.BoxStyle = bsDouble) then
        LB.SelectedIndex := I
      else if (TLayoutRegistry.GetClass(I) = TSingleFrameLayout) and (GLayout.BoxStyle = bsSingle) then
        LB.SelectedIndex := I;
    end;

    Con.SetColor(ccBrightWhite);
    Con.PrintContent(1, 1, 'Layouts (' + IntToStr(Count) + ' registered)');
    Con.ResetColor;

    LB.Draw;
    DrawLayoutPreview;
    Con.ShowStatus(#$25B2 + '/' + #$25BC + ' select    Enter apply    ' + HINT_CONTENT);

    repeat
      Result := Con.ReadKeyCode;
      case Result of
        KEY_UP, KEY_DOWN, KEY_PGUP, KEY_PGDN, KEY_HOME, KEY_END_:
        begin
          if LB.HandleKey(Result) then
            DrawLayoutPreview;
        end;
        KEY_ENTER:
        begin
          ApplySelected;
          Result := RunLayoutsContent;
          Exit;
        end;
        KEY_MOUSE:
        begin
          ME := Con.MouseEvent;
          if ME.Pressed and (ME.Button = mbLeft) then
          begin
            Hit := LB.HitTest(ME.Col, ME.Row);
            if Hit >= 0 then
            begin
              LB.SelectedIndex := Hit;
              LB.Draw;
              DrawLayoutPreview;
            end;
          end;
        end;
        KEY_TAB, KEY_ESCAPE:
          Exit;
      end;
    until False;
  finally
    LB.Free;
  end;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  Tab preview (drawn when tab bar is focused — no interaction)
// ═══════════════════════════════════════════════════════════════════════════

procedure PreviewCurrentTab;
const
  PREVIEWS: array[0..2] of string = (
    'Colour palette — press Enter to interact',
    'Line input test — press Enter to interact',
    'Registered layouts — press Enter to browse and apply'
  );
var
  Idx: Integer;
begin
  Con.ClearContent;
  Idx := GLayout.TabBar.ActiveIndex;
  if (Idx >= Low(PREVIEWS)) and (Idx <= High(PREVIEWS)) then
  begin
    Con.SetColor(ccGray);
    Con.PrintContent(1, 1, PREVIEWS[Idx]);
    Con.ResetColor;
  end;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  Main loop with focus model
// ═══════════════════════════════════════════════════════════════════════════

procedure DrawTitle;
var
  TCol, TRow, TW: Integer;
begin
  GLayout.GetTitleArea(TCol, TRow, TW);
  Con.SetColor(ccBrightYellow);
  Con.PrintAt(TCol, TRow, 'AR.Console Test');
  Con.SetColor(ccGray);
  Con.PrintAt(TCol + 20, TRow, Format('%d x %d', [Con.Width, Con.Height]));
  Con.ResetColor;
end;

procedure SetFocusTabBar;
begin
  GLayout.TabBar.Focused := True;
  GLayout.TabBar.Draw;
  Con.ShowStatus(HINT_TABBAR);
end;

procedure SetFocusContent;
begin
  GLayout.TabBar.Focused := False;
  GLayout.TabBar.Draw;
end;

function EnterContent: Word;
begin
  SetFocusContent;
  case GLayout.TabBar.ActiveIndex of
    0: Result := RunColoursContent;
    1: Result := RunInputContent;
    2: Result := RunLayoutsContent;
  else
    Result := KEY_ESCAPE;
  end;
end;

procedure RunTabbedApp;
var
  Code, Replay: Word;
  PrevTab, HitTab: Integer;
  Done: Boolean;
  ME: TMouseEvent;
begin
  GLayout := TTabbedLayout.Create(Con, bsDouble);
  GLayout.TabBar.SetTabs(['Colours', 'Input', 'Layouts']);
  GLayout.TabBar.AddButton('About', procedure
  begin
    Con.ClearContent;
    Con.SetColor(ccBrightCyan);
    Con.PrintContent(1, 1, 'AR.Console Framework');
    Con.SetColor(ccGray);
    Con.PrintContent(1, 3, 'A lightweight TUI framework for Delphi.');
    Con.PrintContent(1, 4, 'Supports mouse input, colours, layouts, and tabs.');
    Con.PrintContent(1, 5, 'Built with TBarItem polymorphism: TTabItem + TButtonItem.');
    Con.ResetColor;
    Con.ShowStatus('Click a tab or press a key to continue');
  end);
  Con.SetLayout(GLayout);

  Con.EnableMouse;
  DrawTitle;
  PreviewCurrentTab;
  SetFocusTabBar;

  Done := False;
  while not Done do
  begin
    Code := Con.ReadKeyCode;
    PrevTab := GLayout.TabBar.ActiveIndex;

    case Code of
      KEY_LEFT:
      begin
        GLayout.TabBar.SelectPrev;
        if GLayout.TabBar.ActiveIndex <> PrevTab then
          PreviewCurrentTab;
      end;
      KEY_RIGHT, KEY_TAB:
      begin
        GLayout.TabBar.SelectNext;
        if GLayout.TabBar.ActiveIndex <> PrevTab then
          PreviewCurrentTab;
      end;
      KEY_ENTER, KEY_DOWN:
      begin
        Replay := EnterContent;
        SetFocusTabBar;
        PreviewCurrentTab;

        case Replay of
          KEY_LEFT:
          begin
            GLayout.TabBar.SelectPrev;
            PreviewCurrentTab;
          end;
          KEY_RIGHT:
          begin
            GLayout.TabBar.SelectNext;
            PreviewCurrentTab;
          end;
        end;
      end;
      KEY_ESCAPE:
        Done := True;
      KEY_MOUSE:
      begin
        ME := Con.MouseEvent;
        if ME.Pressed and (ME.Button = mbLeft) then
        begin
          HitTab := GLayout.TabBar.HitTest(ME.Col, ME.Row);
          if HitTab >= 0 then
          begin
            if GLayout.TabBar.IsButton(HitTab) then
            begin
              // Button click — fire callback
              TButtonItem(GLayout.TabBar.Items[HitTab]).OnClick();
            end
            else
            begin
              // Tab click — select and enter content
              GLayout.TabBar.SelectTab(HitTab);
              Replay := EnterContent;
              SetFocusTabBar;
              PreviewCurrentTab;
              case Replay of
                KEY_LEFT:  begin GLayout.TabBar.SelectPrev; PreviewCurrentTab; end;
                KEY_RIGHT: begin GLayout.TabBar.SelectNext; PreviewCurrentTab; end;
              end;
            end;
          end;
        end
        // Hover — hand cursor over tab/button labels, arrow elsewhere
        else if ME.Button = mbNone then
        begin
          if GLayout.TabBar.HitTest(ME.Col, ME.Row) >= 0 then
            Con.SetMouseCursor(crPointer)
          else
            Con.SetMouseCursor(crDefault);
        end;
      end;
    else
      if (Code >= Ord('1')) and (Code <= Ord('3')) then
      begin
        GLayout.TabBar.SelectTab(Code - Ord('1'));
        if GLayout.TabBar.ActiveIndex <> PrevTab then
          PreviewCurrentTab;
      end;
    end;
  end;

  Con.DisableMouse;
end;

begin
  try
    RunTabbedApp;
    Con.Clear;
    Con.ShowCursor;
    Con.MoveTo(1, 1);
    Con.PrintLn('Goodbye!');
  except
    on E: Exception do
    begin
      Con.Shutdown;
      Writeln(ErrOutput, E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
