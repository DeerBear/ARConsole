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
    Tab bar focused : Left/Right/Tab cycle tabs, Enter/Down enters content
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
  I, Selected, Count: Integer;
  CCol, CRow, CW, CH: Integer;
  PreviewLeft, PreviewW, PreviewH: Integer;

  procedure DrawLayoutList;
  var
    J: Integer;
    Name: string;
  begin
    for J := 0 to Count - 1 do
    begin
      Name := '  ' + TLayoutRegistry.GetName(J) + '  ';
      Con.PrintContent(1, 3 + J, StringOfChar(' ', 20));
      Con.PrintContent(1, 3 + J, '');

      if J = Selected then
      begin
        Con.SetColor(ccBrightWhite);
        System.Write(ESC + '[7m');
        Con.Print(Name);
        System.Write(ESC + '[27m');
      end
      else
      begin
        Con.SetColor(ccGray);
        Con.Print(Name);
      end;
    end;
    Con.ResetColor;
  end;

  procedure DrawLayoutPreview;
  var
    R: Integer;
    Tmp: TConsoleLayout;
  begin
    // Clear preview area
    for R := CRow + 2 to CRow + 2 + PreviewH do
      Con.PrintAt(PreviewLeft, R, StringOfChar(' ', PreviewW + 2));

    // Let the layout draw its own preview
    Tmp := TLayoutRegistry.CreateLayout(Selected, Con);
    try
      Tmp.DrawPreview(PreviewLeft, CRow + 2, PreviewW, PreviewH);
    finally
      Tmp.Free;
    end;
  end;

begin
  Con.ClearContent;
  GLayout.GetContentArea(CCol, CRow, CW, CH);

  Count := TLayoutRegistry.Count;
  Selected := 0;

  // Match current box style to a registered layout
  for I := 0 to Count - 1 do
  begin
    if (TLayoutRegistry.GetClass(I) = TDoubleFrameLayout) and (GLayout.BoxStyle = bsDouble) then
      Selected := I
    else if (TLayoutRegistry.GetClass(I) = TSingleFrameLayout) and (GLayout.BoxStyle = bsSingle) then
      Selected := I;
  end;

  // Preview dimensions
  PreviewLeft := CCol + 24;
  PreviewW := CW - 26;
  if PreviewW > 40 then PreviewW := 40;
  PreviewH := CH - 3;
  if PreviewH > 10 then PreviewH := 10;

  Con.SetColor(ccBrightWhite);
  Con.PrintContent(1, 1, 'Layouts (' + IntToStr(Count) + ' registered)');
  Con.ResetColor;

  DrawLayoutList;
  DrawLayoutPreview;
  Con.ShowStatus(#$25B2 + '/' + #$25BC + ' select    Enter apply    ' + HINT_CONTENT);

  repeat
    Result := Con.ReadKeyCode;
    case Result of
      KEY_UP:
      begin
        if Selected > 0 then
        begin
          Dec(Selected);
          DrawLayoutList;
          DrawLayoutPreview;
        end;
      end;
      KEY_DOWN:
      begin
        if Selected < Count - 1 then
        begin
          Inc(Selected);
          DrawLayoutList;
          DrawLayoutPreview;
        end;
      end;
      KEY_ENTER:
      begin
        // Apply selected layout's style to the frame
        if TLayoutRegistry.GetClass(Selected) = TSingleFrameLayout then
          GLayout.BoxStyle := bsSingle
        else
          GLayout.BoxStyle := bsDouble;

        Con.Clear;
        GLayout.DrawFrame;
        DrawTitle;
        Result := RunLayoutsContent;
        Exit;
      end;
      KEY_TAB, KEY_ESCAPE:
        Exit;
    end;
  until False;
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
  PrevTab: Integer;
  Done: Boolean;
begin
  GLayout := TTabbedLayout.Create(Con, bsDouble);
  GLayout.TabBar.SetTabs(['Colours', 'Input', 'Layouts']);
  Con.SetLayout(GLayout);

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
    else
      if (Code >= Ord('1')) and (Code <= Ord('3')) then
      begin
        GLayout.TabBar.SelectTab(Code - Ord('1'));
        if GLayout.TabBar.ActiveIndex <> PrevTab then
          PreviewCurrentTab;
      end;
    end;
  end;
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
