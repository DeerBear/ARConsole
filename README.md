# AR.Console

A lightweight, cross-platform TUI (Text User Interface) framework for Delphi.

**Windows + Linux + macOS** from a single codebase. 

## Features

- **Cross-platform** -- Windows (VT100 via SetConsoleMode), Linux and macOS (termios raw mode)
- **Unicode box drawing** -- single-line and double-line frame characters
- **16-colour palette** -- standard + bright ANSI foreground colours
- **Extended key input** -- arrow keys, F-keys, Home/End/PgUp/PgDn with full CSI parsing on POSIX
- **Layout system** -- abstract `TConsoleLayout` base with pluggable concrete layouts
- **Layout registry** -- `TLayoutRegistry` for enumerating and instantiating registered layouts, each with a self-rendering preview
- **Tab bar** -- `TTabBar` with arrow/Tab navigation, focus state (reverse-video / underline), and Enter activation
- **Focus model** -- tab-bar vs content focus with key bubbling via `ReadLine(out AExitKey)`
- **Layout helpers** -- `PrintContent`, `ShowStatus`, `PromptInput` for working relative to the content area
- **Menu system** -- `ShowMenu` draws a framed option list and waits for a keypress

## Architecture

```
Library/
  AR.Console.Base.pas       -- TConsoleBase (abstract), TConsoleLayout (abstract),
                               enums, key codes, box-drawing constants, ANSI output
  AR.Console.Layouts.pas    -- TFrameLayout, TSingleFrameLayout, TDoubleFrameLayout,
                               TTabBar, TTabbedLayout, TLayoutRegistry
  AR.Console.Windows.pas    -- TWindowsConsole : TConsoleBase
  AR.Console.POSIX.pas      -- TPosixConsole : TConsoleBase
  AR.Console.pas            -- TConsole = platform alias + Con singleton

Demo/
  ConsoleTest.dpr           -- Tabbed demo app (Colours, Input, Layouts)
```

Platform selection happens at compile time:

```pascal
uses AR.Console, AR.Console.Base, AR.Console.Layouts;

// TConsole is TWindowsConsole on Windows, TPosixConsole on POSIX.
// Con is a lazily-initialised global singleton.
```

## Quick start

```pascal
uses
  AR.Console.Base, AR.Console.Layouts, AR.Console;

begin
  // Con auto-initialises on first access
  Con.Clear;
  Con.SetColor(ccBrightYellow);
  Con.PrintAt(3, 2, 'Hello from AR.Console!');
  Con.ResetColor;
  Con.ReadKey;
end.
```

### Using a layout

```pascal
var
  Layout: TDoubleFrameLayout;
begin
  Layout := TDoubleFrameLayout.Create(Con);
  Con.SetLayout(Layout);   // Draws the frame immediately

  Con.PrintContent(1, 1, 'Title goes here');
  Con.ShowStatus('Press any key...');
  Con.ReadKey;
end.
```

### Using the tab bar

```pascal
var
  Layout: TTabbedLayout;
begin
  Layout := TTabbedLayout.Create(Con, bsDouble);
  Layout.TabBar.SetTabs(['Tab 1', 'Tab 2', 'Tab 3']);
  Con.SetLayout(Layout);

  // Left/Right/Tab to cycle, Enter to activate
  // See Demo/ConsoleTest.dpr for a complete focus-model example.
end.
```

## Extending

**Add a new layout:** subclass `TConsoleLayout`, implement `DrawFrame`, `DrawPreview`, `GetContentArea`, `GetInputRow`, `GetInputCol`, `GetTitleArea`, and register it:

```pascal
TLayoutRegistry.Register('My Layout', TMyLayout);
```

It will automatically appear in any layout browser that enumerates the registry.

## Tested on

- Delphi 12
- Windows 11

## Should work on
- Any POSIX terminal 

## Author

Andrea Raimondi

## License

MIT
