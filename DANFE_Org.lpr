program DANFE_Org;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, DateUtils, CustApp, 
  {$IFDEF WINDOWS}
  Windows, 
  {$ENDIF}
  Zipper, 
  {$IFDEF UNIX}
  BaseUnix, Unix,
  {$ENDIF}
  {$IFDEF WINDOWS}
  Crt,
  {$ELSE}
  termio,
  {$ENDIF}
  DOM, XMLRead; // Added XML parsing units

type
  TMenuOption = (moReorganize, moCompress, moBoth, moExit);  // adicionado moExit

  { Thread para mover arquivos }
  TFileMoverThread = class(TThread)
  private
    FFileName: string;
    FSourceDir: string;
    FCurrentCount, FTotalCount: Integer;
    FApp: TObject;
  protected
    procedure Execute; override;
    procedure UpdateProgress;
  public
    constructor Create(const AFileName: string; ASourceDir: string; ACurrentCount, ATotalCount: Integer; AApp: TObject);
  end;

  { Aplicação Principal }
  TDANFEORG = class(TCustomApplication)
  private
    procedure OrganizarArquivos;
    procedure CompactarPastas;
    procedure DrawProgressBar(Current, Total: Integer);
    function ShowMenu: TMenuOption;
    function GetEmissionDateFromXML(const XMLFilePath: string): TDateTime;
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

{ =================== TFileMoverThread =================== }

constructor TFileMoverThread.Create(const AFileName: string; ASourceDir: string; ACurrentCount, ATotalCount: Integer; AApp: TObject);
begin
  inherited Create(False);
  FFileName := AFileName;
  FSourceDir := ASourceDir;
  FCurrentCount := ACurrentCount;
  FTotalCount := ATotalCount;
  FApp := AApp;
  FreeOnTerminate := True;
end;

procedure TFileMoverThread.Execute;
var
  SrcFile, DestFolder, DestFile: string;
  FileDateTime: TDateTime;
  Year, Month, Day: Word;
begin
  SrcFile := IncludeTrailingPathDelimiter(FSourceDir) + FFileName;
  
  // Get date from XML instead of file date
  try
    FileDateTime := TDANFEORG(FApp).GetEmissionDateFromXML(SrcFile);
  except
    on E: Exception do
    begin
      // Fallback to file date if XML parsing fails
      FileDateTime := FileDateToDateTime(FileAge(SrcFile));
    end;
  end;
  
  DecodeDate(FileDateTime, Year, Month, Day);
  
  DestFolder := IncludeTrailingPathDelimiter(FSourceDir) +
               IntToStr(Year) + PathDelim +
               Format('%.2d', [Month]);
  
  ForceDirectories(DestFolder);
  DestFile := IncludeTrailingPathDelimiter(DestFolder) + FFileName;
  RenameFile(SrcFile, DestFile);
  
  Synchronize(@UpdateProgress);
end;

procedure TFileMoverThread.UpdateProgress;
begin
  TextColor(Green);
  TDANFEORG(FApp).DrawProgressBar(FCurrentCount, FTotalCount);
  TextColor(LightGray);
end;

{ =================== TDANFEORG =================== }

procedure TDANFEORG.DrawProgressBar(Current, Total: Integer);
const
  BAR_CHAR = '=';     // caractere para a barra
  EMPTY_CHAR = '-';    // caractere para espaço vazio
  BAR_WIDTH = 40;      // largura fixa da barra
var
  i, Filled: Integer;
  Percent: Integer;
begin
  if Total = 0 then Exit;
  
  // Calcula preenchimento
  Percent := Round((Current / Total) * 100);
  Filled := Round((Current / Total) * BAR_WIDTH);
  
  // Volta para início da linha
  Write(#13);
  
  // Desenha a barra
  TextColor(White);
  Write('[');
  TextColor(Green);
  for i := 1 to Filled do
    Write(BAR_CHAR);
  TextColor(LightGray);
  for i := Filled + 1 to BAR_WIDTH do
    Write(EMPTY_CHAR);
  Write('] ', Percent:3, '% (', Current:4, '/', Total:4, ')    ');  // espaços extras para limpar
  
  if Current = Total then
  begin
    WriteLn;
    WriteLn('Processo concluído com sucesso! ', Total, ' arquivos organizados.');
  end;
end;

procedure TDANFEORG.OrganizarArquivos;
var
  Files: TStringList;
  SR: TSearchRec;
  I: Integer;
  FileDateTime: TDateTime;
  DestFolder: string;
  Year, Month, Day: Word;
  SourceDir: string;
  CurrentPath: string;
begin
  // Changed: Use the executable's directory rather than the current directory
  CurrentPath := ExtractFilePath(ParamStr(0));
  SourceDir := CurrentPath;
  
  Files := TStringList.Create;
  try
    if FindFirst(IncludeTrailingPathDelimiter(CurrentPath)+'*.xml', faAnyFile, SR) = 0 then
    begin
      repeat
        Files.Add(IncludeTrailingPathDelimiter(CurrentPath) + SR.Name);
      until FindNext(SR) <> 0;
      FindClose(SR.FindHandle);  // modificado: usar FindHandle
    end;
    
    if Files.Count = 0 then
    begin
      WriteLn('Nenhum arquivo XML encontrado na pasta atual.');
      Exit;
    end;

    WriteLn('Encontrados ', Files.Count, ' arquivos XML');
    WriteLn('Iniciando organização...');
    WriteLn;

    for I := 0 to Files.Count - 1 do
    begin
      // Get date from XML instead of file date
      try
        FileDateTime := GetEmissionDateFromXML(Files[I]);
      except
        on E: Exception do
        begin
          // Fallback to file date if XML parsing fails
          FileDateTime := FileDateToDateTime(FileAge(Files[I]));
        end;
      end;
      
      DecodeDate(FileDateTime, Year, Month, Day);
      
      DestFolder := IncludeTrailingPathDelimiter(CurrentPath) +
                   IntToStr(Year) + PathDelim +
                   Format('%.2d', [Month]);
      
      ForceDirectories(DestFolder);
      
      if RenameFile(Files[I], IncludeTrailingPathDelimiter(DestFolder) + ExtractFileName(Files[I])) then
        DrawProgressBar(I + 1, Files.Count)
      else
        WriteLn(#13, 'Erro ao mover: ', ExtractFileName(Files[I]));
    end;
  finally
    Files.Free;
  end;
end;

procedure TDANFEORG.CompactarPastas;
var
  Zipper: TZipper;
  CurrentPath: string;
  TotalFiles, ProcessedFiles: Integer;
  DirRec: TSearchRec;

  { Recursively counts files in a directory }
  function CountFiles(const Dir: string): Integer;
  var
    Rec: TSearchRec;
    Count: Integer;
  begin
    Count := 0;
    if FindFirst(IncludeTrailingPathDelimiter(Dir)+'*', faAnyFile, Rec) = 0 then
    begin
      repeat
        if (Rec.Name <> '.') and (Rec.Name <> '..') then
        begin
          if (Rec.Attr and faDirectory) <> 0 then
            Inc(Count, CountFiles(IncludeTrailingPathDelimiter(Dir)+Rec.Name))
          else
            Inc(Count);
        end;
      until FindNext(Rec) <> 0;
      FindClose(Rec.FindHandle);
    end;
    Result := Count;
  end;

  { Recursively adds files to the ZIP }
  procedure AddFiles(const Dir, RelPath: string);
  var
    Rec: TSearchRec;
    FullPath, ArchiveName: string;
  begin
    if FindFirst(IncludeTrailingPathDelimiter(Dir)+'*', faAnyFile, Rec) = 0 then
    begin
      repeat
        if (Rec.Name <> '.') and (Rec.Name <> '..') then
        begin
          FullPath := IncludeTrailingPathDelimiter(Dir)+Rec.Name;
          if (Rec.Attr and faDirectory) <> 0 then
            AddFiles(FullPath, RelPath + Rec.Name + '/')
          else
          begin
            ArchiveName := RelPath + Rec.Name;
            Zipper.Entries.AddFileEntry(FullPath, ArchiveName);
            Inc(ProcessedFiles);
            DrawProgressBar(ProcessedFiles, TotalFiles);
          end;
        end;
      until FindNext(Rec) <> 0;
      FindClose(Rec.FindHandle);
    end;
  end;

begin
  // Changed: Use the executable's directory
  CurrentPath := ExtractFilePath(ParamStr(0));
  TotalFiles := 0;
  ProcessedFiles := 0;

  // Count all files recursively from each subfolder in CurrentPath
  if FindFirst(CurrentPath + '*', faDirectory, DirRec) = 0 then
  begin
    repeat
      if (DirRec.Name <> '.') and (DirRec.Name <> '..') then
      begin
        if (DirRec.Attr and faDirectory) <> 0 then
          Inc(TotalFiles, CountFiles(IncludeTrailingPathDelimiter(CurrentPath)+DirRec.Name));
      end;
    until FindNext(DirRec) <> 0;
    FindClose(DirRec.FindHandle);
  end;

  if TotalFiles = 0 then
  begin
    WriteLn('Nenhuma pasta encontrada para compactar.');
    Exit;
  end;

  Zipper := TZipper.Create;
  try
    Zipper.FileName := IncludeTrailingPathDelimiter(CurrentPath) + 'DANFE.zip';
    Zipper.Clear;  // Garante limpeza antes de adicionar arquivos.

    WriteLn('Compactando arquivos...');

    // Add files recursively from each subfolder in CurrentPath
    if FindFirst(CurrentPath + '*', faDirectory, DirRec) = 0 then
    begin
      repeat
        if (DirRec.Name <> '.') and (DirRec.Name <> '..') then
        begin
          if (DirRec.Attr and faDirectory) <> 0 then
            AddFiles(IncludeTrailingPathDelimiter(CurrentPath)+DirRec.Name, DirRec.Name + '/');
        end;
      until FindNext(DirRec) <> 0;
      FindClose(DirRec.FindHandle);
    end;

    if Zipper.Entries.Count > 0 then
      Zipper.ZipAllFiles;

    WriteLn;
    WriteLn('Arquivos compactados com sucesso em DANFE.zip.');
  finally
    Zipper.Free;
  end;
end;

function TDANFEORG.GetEmissionDateFromXML(const XMLFilePath: string): TDateTime;
var
  Doc: TXMLDocument;
  RootNode, NFe, infNFe, ide, dhEmi: TDOMNode;
  EmissionDateStr: string;
begin
  Result := Now; // Default to current date in case of failure
  
  try
    ReadXMLFile(Doc, XMLFilePath);
    try
      RootNode := Doc.DocumentElement;
      if RootNode = nil then Exit;
      
      // Navigate the XML structure to find the dhEmi element
      NFe := RootNode.FindNode('NFe');
      if NFe = nil then Exit;
      
      infNFe := NFe.FindNode('infNFe');
      if infNFe = nil then Exit;
      
      ide := infNFe.FindNode('ide');
      if ide = nil then Exit;
      
      dhEmi := ide.FindNode('dhEmi');
      if dhEmi = nil then Exit;
      
      EmissionDateStr := dhEmi.TextContent;
      
      // Parse ISO 8601 date format: 2023-12-29T00:00:00-03:00
      if EmissionDateStr <> '' then
        Result := ISO8601ToDate(EmissionDateStr);
    finally
      Doc.Free;
    end;
  except
    on E: Exception do
    begin
      // Silently handle errors and default to file date
      Result := FileDateToDateTime(FileAge(XMLFilePath));
    end;
  end;
end;

{$IFDEF UNIX}
// Linux-specific key reading function
function ReadKeyLinux: char;
var
  termios: termios;
  c: char;
begin
  TCGetAttr(1, termios);
  termios.c_lflag := termios.c_lflag and not (ICANON or ECHO);
  TCSetAttr(1, TCSANOW, termios);
  read(stdin, c);
  Result := c;
  termios.c_lflag := termios.c_lflag or (ICANON or ECHO);
  TCSetAttr(1, TCSANOW, termios);
end;
{$ENDIF}

function TDANFEORG.ShowMenu: TMenuOption;
var
  Options: array[0..3] of string = (
    'Reorganizar arquivos',
    'Compactar pastas',
    'Reorganizar e compactar',
    'Sair'
  );
  CurrentIndex: Integer;
  Key: char;
  procedure DisplayMenu;
  var
    I: Integer;
  begin
    {$IFDEF WINDOWS}
    ClrScr; // Windows CRT clear screen
    {$ELSE}
    Write(#27'[2J'#27'[H'); // ANSI escape sequence to clear screen
    {$ENDIF}
    WriteLn('DANFE Organizer - Menu Principal');
    WriteLn('-------------------------------');
    for I := 0 to High(Options) do
    begin
      if I = CurrentIndex then
      begin
        {$IFDEF WINDOWS}
        TextColor(White);
        TextBackground(Blue);
        {$ELSE}
        Write(#27'[1;37m'#27'[44m'); // White text, Blue background in ANSI
        {$ENDIF}
        WriteLn(Options[I]);
        {$IFDEF WINDOWS}
        TextColor(LightGray);
        TextBackground(Black);
        {$ELSE}
        Write(#27'[0m'); // Reset text formatting in ANSI
        {$ENDIF}
      end else
        WriteLn(Options[I]);
    end;
    WriteLn('-------------------------------');
    WriteLn('Use as setas para navegar e ENTER para selecionar');
  end;
begin
  CurrentIndex := 0;
  repeat
    DisplayMenu;
    {$IFDEF WINDOWS}
    Key := ReadKey;
    {$ELSE}
    Key := ReadKeyLinux;
    {$ENDIF}
    if Key = #0 then
    begin
      {$IFDEF WINDOWS}
      Key := ReadKey;
      {$ELSE}
      Key := ReadKeyLinux;
      {$ENDIF}
      case Key of
        #72: if CurrentIndex > 0 then Dec(CurrentIndex); // seta para cima
        #80: if CurrentIndex < High(Options) then Inc(CurrentIndex); // seta para baixo
        // ANSI arrow keys for Linux
        'A': if CurrentIndex > 0 then Dec(CurrentIndex); // Up arrow
        'B': if CurrentIndex < High(Options) then Inc(CurrentIndex); // Down arrow
      end;
    end else if Key = #13 then Break; // ENTER seleciona
  until False;
  case CurrentIndex of
    0: Result := moReorganize;
    1: Result := moCompress;
    2: Result := moBoth;
    3: Result := moExit;
  else
    Result := moExit;
  end;
end;

procedure TDANFEORG.DoRun;
var
  Option: TMenuOption;
begin
  try
    Option := ShowMenu;
    case Option of
      moReorganize: 
        begin
          WriteLn('Iniciando reorganização de arquivos...');
          OrganizarArquivos;
        end;
      moCompress:
        begin
          WriteLn('Iniciando compactação...');
          CompactarPastas;
        end;
      moBoth:
        begin
          WriteLn('Iniciando reorganização e compactação...');
          OrganizarArquivos;
          CompactarPastas;
        end;
      moExit: 
        WriteLn('Saindo do programa...');  // opcao de saída
    end;
  except
    on E: Exception do
      WriteLn('Erro: ', E.Message);
  end;
  Write('Pressione qualquer tecla para sair...');
  ReadKey;
  Terminate;
end;

constructor TDANFEORG.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
end;

destructor TDANFEORG.Destroy;
begin
  inherited Destroy;
end;

var
  Application: TDANFEORG;
begin
  Application := TDANFEORG.Create(nil);
  Application.Title := 'DANFEOrganizer';
  Application.Run;
  Application.Free;
end.

