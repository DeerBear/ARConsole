unit AR.Console;

{******************************************************************************
  AR.Console — Platform-selecting façade

  Detects the active platform at compile time and defines:

    TConsole = TWindowsConsole   (when MSWINDOWS)
    TConsole = TPosixConsole     (when POSIX)

  Application code uses only AR.Console + AR.Console.Base in its uses
  clause.  The platform units are pulled in automatically.

  Also provides the Con singleton — a lazily-initialised global TConsole
  that auto-cleans in finalization.

  (c) 2024 - Signal-Based LLM POC
******************************************************************************}

interface

uses
  System.SysUtils,
  AR.Console.Base,
  AR.Console.Windows,
  AR.Console.POSIX;

type
  {$IFDEF MSWINDOWS}
  TConsole = TWindowsConsole;
  {$ENDIF}
  {$IFDEF POSIX}
  TConsole = TPosixConsole;
  {$ENDIF}

function Con: TConsole;

implementation

var
  GSingleton: TConsole = nil;

function Con: TConsole;
begin
  if GSingleton = nil then
  begin
    GSingleton := TConsole.Create;
    GSingleton.Init;
  end;
  Result := GSingleton;
end;

initialization

finalization
  FreeAndNil(GSingleton);

end.
