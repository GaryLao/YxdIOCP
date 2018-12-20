unit uServer;

interface

uses
  Iocp, iocp.Utils.Hash, iocp.Http, iocp.Http.Websocket,
  Windows, SysUtils, Classes, SyncObjs;
  
type
  /// <summary>
  /// ��־��Ϣ����
  /// </summary>
  TXLogType = (log_Debug, {������Ϣ} log_Info {��Ϣ}, log_Warning {����},
    log_Error {����});

type
  /// <summary>
  /// ��־д�봦��
  /// </summary>
  TOnWriteLog = procedure (Sender: TObject; AType: TXLogType;
    const Log: string) of object;

  /// <summary>
  /// ����������
  /// </summary>
  TOnProcRequest = procedure (Request: TIocpHttpRequest; Response: TIocpHttpResponse) of object;

  /// <summary>
  /// HTTP����ϵͳ
  /// </summary>
  TPtService = class(TObject)
  private
    //FPtWebService: TIocpHttpServer;
    FPtWebService: TIocpWebSocketServer;
    FOnWriteLog: TOnWriteLog;
    HttpReqRef: Integer;
    FProcList: TStringHash;
    FHtmlFileExts: TStringHash;
    function GetWebService: TIocpHttpServer;
  protected
    function IsDestroying: Boolean;
    procedure Log(Sender: TObject; AType: TXLogType; const Msg: string);
    procedure LogD(Sender: TObject; const Msg: string);
    procedure LogE(Sender: TObject; const Title: string; E: Exception);
    procedure DoWriteLog(Sender: TObject; AType: TXLogType; const Msg: string);
  protected
    procedure DoRequest(Sender: TIocpHttpServer; Request: TIocpHttpRequest; Response: TIocpHttpResponse);
    procedure DoWebSocketRequest(Sender: TIocpWebSocketServer; Request: TIocpWebSocketRequest; Response: TIocpWebSocketResponse);
    procedure DoRegProc(); virtual; abstract;
    procedure DoFreeProcItem(Item: PHashItem);
  public
    constructor Create(Port: Word); reintroduce;
    destructor Destroy; override;

    procedure RegProc(const URI: string; const Proc: TOnProcRequest);

    procedure Start;
    procedure Stop;

    property WebService: TIocpHttpServer read GetWebService;
  end;

type
  TPtHttpService = class(TPtService)
  protected
    procedure DoRegProc(); override;
    procedure RequestDemo03(Request: TIocpHttpRequest; Response: TIocpHttpResponse);
    procedure RequestHello(Request: TIocpHttpRequest; Response: TIocpHttpResponse);
    procedure RequestUpfile(Request: TIocpHttpRequest; Response: TIocpHttpResponse);
  end;

implementation

type
  PMethod = ^TMethod;

{ TPtService }

constructor TPtService.Create(Port: Word);
begin
  FOnWriteLog := DoWriteLog;
  //FPtWebService := TIocpHttpServer.Create(nil);
  FPtWebService := TIocpWebSocketServer.Create(nil);
  FPtWebService.ListenPort := Port;
  FPtWebService.UploadMaxDataSize := 1024 * 1024;
  FPtWebService.MaxTaskWorker := 64;
  FPtWebService.MaxContextPoolSize := 1;
  FPtWebService.AccessControlAllow.Methods := 'GET,POST,PUT,DELETE,OPTIONS';
  FPtWebService.AccessControlAllow.Headers := 'x-requested-with,content-type';
  FPtWebService.AccessControlAllow.Enabled := True;
  FPtWebService.OnHttpRequest := DoRequest;
  FPtWebService.OnWebSocketRequest := DoWebSocketRequest;

  FProcList := TStringHash.Create();
  FProcList.OnFreeItem := DoFreeProcItem;

  FHtmlFileExts := TStringHash.Create();
  FHtmlFileExts.Add('.html', 1);
  FHtmlFileExts.Add('.htm', 1);
  FHtmlFileExts.Add('.xml', 1);
  FHtmlFileExts.Add('.xmls', 1);
  FHtmlFileExts.Add('.json', 1);

  DoRegProc(); 
end;

destructor TPtService.Destroy;
begin
  try
    Stop;
    FreeAndNil(FPtWebService);
    FreeAndNil(FProcList);
    FreeAndNil(FHtmlFileExts);
  except
    LogE(Self, 'DoDestroy', Exception(ExceptObject));  
  end;
  inherited Destroy;
end;

procedure TPtService.DoFreeProcItem(Item: PHashItem);
begin
  if Item <> nil then
    Dispose(Pointer(Item.Value));
end;

procedure TPtService.DoRequest(Sender: TIocpHttpServer;
  Request: TIocpHttpRequest; Response: TIocpHttpResponse);
var
  V: Number;
begin
  InterlockedIncrement(HttpReqRef);
  //LogD(Self, Request.Header);
  //LogD(Self, Request.DataString);
  V := FProcList.ValueOf(LowerCase(string(Request.URI)));
  if V <> -1 then begin
    TOnProcRequest(PMethod(Pointer(V))^)(Request, Response);
  end else
    Response.SendFileByURI(Request.URI, '', False, True);
end;

procedure TPtService.DoWebSocketRequest(Sender: TIocpWebSocketServer;
  Request: TIocpWebSocketRequest; Response: TIocpWebSocketResponse);
var
  S: TMemoryStream;
  Data: string;
begin
  //OutputDebugString(PChar(Request.DataString()));
  S := TMemoryStream.Create;
  try
    Data := Request.DataString(hct_UTF8);
    S.Write(Data[1], Length(Data) {$IFDEF UNICODE} shl 1{$ENDIF});
    S.Position := 0;
    Response.Send(S, wso_Text);
  finally
    S.Free;
  end;
  Response.Send(Request.DataString());
end;

procedure TPtService.DoWriteLog(Sender: TObject; AType: TXLogType;
  const Msg: string);
begin
  OutputDebugString(PChar(Msg));
end;

function TPtService.GetWebService: TIocpHttpServer;
begin
  Result := FPtWebService;
end;

function TPtService.IsDestroying: Boolean;
begin
  Result := (not Assigned(Self));
end;

procedure TPtService.Log(Sender: TObject; AType: TXLogType; const Msg: string);
begin
  if Assigned(FOnWriteLog) and (not IsDestroying) then
    FOnWriteLog(Sender, AType, Msg);  
end;

procedure TPtService.LogD(Sender: TObject; const Msg: string);
begin
  if Assigned(FOnWriteLog) and (not IsDestroying) then
    FOnWriteLog(Sender, log_Debug, Msg);
end;

procedure TPtService.LogE(Sender: TObject; const Title: string; E: Exception);
begin
  if Assigned(FOnWriteLog) and (not IsDestroying) then begin
    if E = nil then
      FOnWriteLog(Sender, log_Error, Format('[%s] %s', [Sender.ClassName, Title]))
    else
      FOnWriteLog(Sender, log_Error, Format('[%s] %s Error: %s',
        [Sender.ClassName, Title, E.Message]))
  end;
end;

procedure TPtService.RegProc(const URI: string; const Proc: TOnProcRequest);
var
  P: PMethod;
begin
  if Length(URI) = 0 then Exit;
  if Assigned(Proc) then begin
    New(P);
    P^ := TMethod(Proc);
    FProcList.Add(LowerCase(URI), Integer(P));
  end;
end;

procedure TPtService.Start;
begin
  FPtWebService.Open;
end;

procedure TPtService.Stop;
begin
  FPtWebService.Close;
end;  

{ TPtHttpService }

procedure TPtHttpService.DoRegProc;
begin
  RegProc('/RequestDemo03.o', RequestDemo03);
  RegProc('/Hello', RequestHello);
  RegProc('/upfile', RequestUpfile);
end;

procedure TPtHttpService.RequestDemo03(Request: TIocpHttpRequest;
  Response: TIocpHttpResponse);
var
  O: TIocpHttpWriter;
begin
  O := Response.GetOutWriter();
  O.Charset := hct_GB2312;
  O.Write('Data: ').Write(Request.GetDataString(string(Request.CharSet))).Write('<br>');
  O.Write('���: ').Write(Request.GetParam('userid')).Write('<br>');
  O.Write('�û���: ').Write(Request.GetParam('username')).Write('<br>');
  O.Write('����: ').Write(Request.GetParam('userpass')).Write('<br>');
  O.Write('�Ա�: ').Write(Request.GetParam('sex')).Write('<br>');
  O.Write('����: ').Write(Request.GetParam('dept')).Write('<br>');
  O.Write('��Ȥ: ').Write(Request.GetParamValues('inst')).Write('<br>');
  O.Write('˵��: ').Write(Request.GetParam('note')).Write('<br>');
  O.Write('��������: ').Write(Request.GetParam('hiddenField')).Write('<br>');
  O.Flush;
end;

procedure TPtHttpService.RequestHello(Request: TIocpHttpRequest;
  Response: TIocpHttpResponse);
begin
  Response.Send('Hello');
end;

// �ϴ��ļ�����
procedure TPtHttpService.RequestUpfile(Request: TIocpHttpRequest;
  Response: TIocpHttpResponse);
const
  UpFileDir = 'files';
var
  S: TStream;
  F: TFileStream;
  FName, Path: string;
begin
  if Request.IsPost and Request.IsFormData then begin // �ж��Ƿ�Ϊ������
    F := nil;
    with Request.FormData['fname'] do begin // ���е��ļ������ֶ�
      S := GetContentStream;  // ������
      if Assigned(S) then begin
        S.Position := 0;
        try
          // �õ��ļ�����λ��
          Path := Request.Owner.WebPath + UpFileDir + '\';
          if not DirectoryExists(Path) then
            ForceDirectories(Path);
          // ����һ���ļ���
          FName := FileName;
          while FileExists(Path + FName) do begin
            FName := FormatDateTime('HHMMSSZZZ', Now) + FileName;
          end;
          // д���ļ�
          F := TFileStream.Create(Path + FName, fmCreate);
          F.CopyFrom(S, S.Size);
        finally
          FreeAndNil(F);
          S.Free;
        end;
        // ����״̬�������
        Response.Send(
          Format('{"result":"success.","ObjectFileName":"%s","SourceFileName":"%s"}',
            [UpFileDir + '/' + FName, FileName]));
      end else
        Response.Send('��Ч��������');
    end;
  end else
    Response.ErrorRequest();
end;

initialization

finalization

end.