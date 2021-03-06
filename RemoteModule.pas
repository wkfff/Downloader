unit RemoteModule;

interface

uses
  Windows, Classes, SysUtils, UnitFuc, UnitLoadDll, UnitMemFuc, MD5Unit,
  UnitCompress, UnitType;

type
  
  TRMInit = function(lpWebID: PWideChar; lpSoftID: PWideChar): LongBool;
    stdcall;
  TRMUninit = function(): LongBool; stdcall;

  TRMGetWebXml = function(lpXML: PWideChar; lpXMLOut: PPWideChar): LongBool;
    stdcall;
  TRMGetSoftXml = function(lpXML: PWideChar; lpXMLOut: PPWideChar): LongBool;
    stdcall;

  TRMRunCreateTask = function(lpTask: PTaskInfo): LongBool; stdcall;
  TRMStartInstall = function(nStepNumber: Integer; bInstallMain: LongBool;
    bOnlySilent: LongBool): LongBool; stdcall;
  TRMStartInstallEnd = function(nStepNumber: Integer; bInstallMain: LongBool;
    bOnlySilent: LongBool): LongBool; stdcall;

  TRMAppEnd = function(nExitCode: Integer): LongBool; stdcall;

  TRMPlugsAPI = record
    lpRMInit: TRMInit;
    lpRMUninit: TRMUninit;
    lpRMGetWebXml: TRMGetWebXml;
    lpRMGetSoftXml: TRMGetSoftXml;
    lpRMRunCreateTask: TRMRunCreateTask;
    lpRMStartInstall: TRMStartInstall;
    lpRMStartInstallEnd: TRMStartInstallEnd;
    lpRMAppEnd: TRMAppEnd;
  end;
  
  TRomoteManager = class
  private
    FIsLoaded: Boolean;
    FModule: MODULE_HANDLE;
    FRMApi: TRMPlugsAPI;
  protected
    function LoadModuleAPI(): Boolean;
  public
    constructor Create();
    destructor Destroy(); override;
    function LoadFromUrl(const URL: string; const MD5: string;
      bIsCompress: Boolean = True): Boolean;
    function LoadFromStream(stream: TMemoryStream): Boolean;
  public
    function RMInit(strWeb: string; strSoft: string): Boolean;
    function RMUninit(): Boolean;

    function RMGetWebXml(var strXML: string): Boolean;
    function RMRMGetSoftXml(var strXML: string): Boolean;

    function RMRunCreateTask(lpTask: PTaskInfo): Boolean;
    function RMStartInstall(nStepNumber: Integer; bInstallMain: LongBool;
      bOnlySilent: LongBool): Boolean;
    function RMStartInstallEnd(nStepNumber: Integer; bInstallMain: LongBool;
      bOnlySilent: LongBool): Boolean;

    function RMAppEnd(nExitCode: Integer): Boolean;
  published
    property IsLoaded: Boolean read FIsLoaded write FIsLoaded;
  end;

implementation

constructor TRomoteManager.Create;
begin
  FIsLoaded := False;
  FModule := nil;
end;

destructor TRomoteManager.Destroy;
begin

  inherited;
end;

function TRomoteManager.LoadFromStream(stream: TMemoryStream): Boolean;
begin
  Result := False;
  stream.Position := 0;
  FModule := LoadModuleFromMemory(stream.Memory, stream.Size);
  Result := Assigned(FModule);

  FIsLoaded := Result;
  if (Result) then
    LoadModuleAPI();
end;

function TRomoteManager.LoadFromUrl(const URL, MD5: string;
  bIsCompress: Boolean): Boolean;
var
  memStream, deStream: TMemoryStream;
begin
  Result := False;
  try
    memStream := TMemoryStream.Create;
    try
      if (GetWebStream(URL, memStream) and (memStream.Size > 0)) then
      begin
        memStream.Position := 0;
        if LowerCase(MD5PrintW(MD5Stream(memStream))) = LowerCase(MD5) then
        begin
          if (bIsCompress) then
          begin
            deStream := TMemoryStream.Create;
            try
              DecompressStream(memStream, deStream);
              Result := LoadFromStream(deStream);
            finally
              deStream.Free;
            end;
          end
          else
            Result := LoadFromStream(memStream);
        end;
      end;
    finally
      memStream.Free;
    end;
  except
  end;
end;

function TRomoteManager.LoadModuleAPI: Boolean;
begin
  Result := False;
  if (not Assigned(FModule)) then
    Exit;
  with FRMApi do
  begin
    lpRMInit := GetModuleFunction(FModule, 'RMInit');
    lpRMUninit := GetModuleFunction(FModule, 'RMUninit');
    lpRMGetWebXml := GetModuleFunction(FModule, 'RMGetWebXml');
    lpRMGetSoftXml := GetModuleFunction(FModule, 'RMGetSoftXml');
    lpRMRunCreateTask := GetModuleFunction(FModule, 'RMRunCreateTask');
    lpRMStartInstall := GetModuleFunction(FModule, 'RMStartInstall');
    lpRMStartInstallEnd := GetModuleFunction(FModule, 'RMStartInstallEnd');
    lpRMAppEnd := GetModuleFunction(FModule, 'RMAppEnd');

    Result := Assigned(lpRMInit);
  end;

end;

function TRomoteManager.RMAppEnd(nExitCode: Integer): Boolean;
begin
  Result := False;
  if FIsLoaded and Assigned(FRMApi.lpRMAppEnd) then
  begin
    Result := FRMApi.lpRMAppEnd(nExitCode);
  end;
end;

function TRomoteManager.RMGetWebXml(

  var strXML: string): Boolean;
var
  ppStr: PWideChar;
begin
  Result := False;
  if FIsLoaded and Assigned(FRMApi.lpRMGetWebXml) then
  begin
    ppStr := nil;
    Result := FRMApi.lpRMGetWebXml(PChar(strXML), @ppStr);
    if Result and Assigned(ppStr) then
    begin
      strXML := ppStr;
    end;
  end;
end;

function TRomoteManager.RMInit(strWeb, strSoft: string): Boolean;
begin
  Result := False;
  if FIsLoaded and Assigned(FRMApi.lpRMInit) then
  begin
    Result := FRMApi.lpRMInit(PChar(strWeb), PChar(strSoft));
  end;
end;

function TRomoteManager.RMRMGetSoftXml(var strXML: string): Boolean;
var
  ppStr: PWideChar;
begin
  Result := False;
  if FIsLoaded and Assigned(FRMApi.lpRMGetSoftXml) then
  begin
    ppStr := nil;
    Result := FRMApi.lpRMGetSoftXml(PChar(strXML), @ppStr);
    if Result and Assigned(ppStr) then
    begin
      strXML := ppStr;
    end;
  end;
end;

function TRomoteManager.RMRunCreateTask(lpTask: PTaskInfo): Boolean;
begin
  Result := False;
  if FIsLoaded and Assigned(FRMApi.lpRMRunCreateTask) then
  begin
    Result := FRMApi.lpRMRunCreateTask(lpTask);
  end;
end;

function TRomoteManager.RMStartInstall(nStepNumber: Integer;
  bInstallMain, bOnlySilent: LongBool): Boolean;
begin
  Result := False;
  if FIsLoaded and Assigned(FRMApi.lpRMStartInstall) then
  begin
    Result := FRMApi.lpRMStartInstall(nStepNumber, bInstallMain, bOnlySilent);
  end;
end;

function TRomoteManager.RMStartInstallEnd(nStepNumber: Integer;
  bInstallMain, bOnlySilent: LongBool): Boolean;
begin
  Result := False;
  if FIsLoaded and Assigned(FRMApi.lpRMStartInstallEnd) then
  begin
    Result := FRMApi.lpRMStartInstallEnd(nStepNumber, bInstallMain,
      bOnlySilent);
  end;
end;

function TRomoteManager.RMUninit: Boolean;
begin
  Result := False;
  if FIsLoaded and Assigned(FRMApi.lpRMUninit) then
  begin
    Result := FRMApi.lpRMUninit();
  end;
end;

end.
 