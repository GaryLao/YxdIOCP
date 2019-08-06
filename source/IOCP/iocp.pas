{*******************************************************}
{                                                       }
{       IOCP ��Ԫ  (����Ԫ�Ѿ���װ���ж�����)           }
{                                                       }
{       ��Ȩ���� (C) 2015 YangYxd (����DIOCP�޸İ汾)   }
{                                                       }
{*******************************************************}
{
  ˵���� ����Ԫ���ɱ���Ŀ�������ⲿ��ֱ��ʹ�õ�ģ����࣬
  ��ʹ��ʱ����ֻ��Ҫ���ñ���Ԫ�Ϳ������㳣��ʹ�á�

  ��л DIOCP ��Ŀ��������ң�����Ŀ��������������DIOCP��
  ���Һ��Ĳ����޸ĺ��٣�ԭ���Ѿ��ǳ��ȶ�����Ҫ�Ǽ򻯵�ʹ
  �÷�ʽ���Դ�����������������������HTTP����

  ��Դ����ԭ���߽��ƣ���������⸴�ơ��޸ġ�ʹ�ã��緢��
  BUG�뱨������ǡ�Ϊ�˳�����Դ�����һ���޸İ汾������
  ϣ��Ҳ�ܿ�Դ��

  ���棺ʹ�ñ���ĿԴ�������һ�к����ʹ�������и���

  DIOCP�ٷ�QQȺ��320641073
  QDAC�ٷ�QQȺ��250530692
  
  Github: https://github.com/yangyxd/YxdIOCP  
}

unit iocp;

{$I 'iocp.inc'}
// �Ƿ����� TIocpHttpServer
{$DEFINE UseHttpServer}
{$IFDEF UseHttpServer}
{$DEFINE UseWebSocketServer}
  {$IF (RTLVersion>=26)}
  {$DEFINE UseWebMvcServer}
  {$IFEND}
{$ENDIF}

interface

{$R YxdIocpIcon.res}

uses
  iocp.Utils.Hash, 
  {$IFDEF UseHttpServer}iocp.Http, {$ENDIF}
  {$IFDEF UseWebSocketServer}iocp.Http.WebSocket, {$ENDIF}
  {$IFDEF UseWebMvcServer}iocp.Http.MVC, {$ENDIF}
  iocp.Sockets, iocp.Task, iocp.Winapi.TlHelp32, iocp.Utils.MemPool,
  iocp.Sockets.Utils, iocp.Core.Engine, iocp.Res, iocp.RawSockets,
  iocp.Utils.Queues, iocp.Utils.ObjectPool, WinSock,
  SyncObjs, Windows, Classes, SysUtils;

{$IFDEF SupportEx}
const
  SupportCurrentPlatforms = pidWin32 or pidWin64;
{$ENDIF}

type
  TIocpStateMsgType = iocp.Sockets.TIocpStateMsgType;
  
type
  TIocpContext = iocp.Sockets.TIocpCustomContext;

type
  TMemPool = iocp.Utils.MemPool.TYXDMemPool;
  TIocpMemPool = iocp.Utils.MemPool.TIocpMemPool;
  TIocpStream = iocp.Utils.MemPool.TIocpStream;
  TIocpSocketStream = iocp.Sockets.TIocpBlockSocketStream;

type
  /// <summary>
  /// ������ UDP Scoket
  /// </summary>
  {$IFDEF SupportEx}[ComponentPlatformsAttribute(SupportCurrentPlatforms)]{$ENDIF}
  TIocpUdpSocket = class(iocp.Sockets.TIocpCustomBlockUdpSocket)
  end;

type
  /// <summary>
  /// ������ TCP Scoket
  /// </summary>
  {$IFDEF SupportEx}[ComponentPlatformsAttribute(SupportCurrentPlatforms)]{$ENDIF}
  TIocpTcpSocket = class(TIocpCustomBlockTcpSocket)
  end;

type
  /// <summary>
  /// ������Iocp����� (��������)
  /// </summary>
  {$IFDEF SupportEx}[ComponentPlatformsAttribute(SupportCurrentPlatforms)]{$ENDIF}
  TIocpTcpServer = class(TIocpCustomTcpServer)
  end;

type
  /// <summary>
  /// �����ܶ�����Iocp�ͻ��� (�첽ͨѶ)
  /// </summary>
  {$IFDEF SupportEx}[ComponentPlatformsAttribute(SupportCurrentPlatforms)]{$ENDIF}
  TIocpTcpClient = class(TIocpCustomTcpClient)
  end;

type
  /// <summary>
  /// Iocp UDP ����� ���������ܣ�
  /// </summary>
  TIocpUdpServer = iocp.Sockets.TIocpUdpServer;
  TIocpUdpRequest = iocp.Sockets.TIocpUdpRequest;

type
  TIocpTcpCodecServer = class;
  TIocpConnection = class;
  
  TOnRecvExecute = procedure (Sender: TIocpTcpCodecServer;
    AConnection: TIocpConnection; var RequestData: TObject) of object;
  TOnDecodeData = function (Connection: TIocpConnection; const Stream: TIocpStream; var Request: TObject): Boolean of object;

  PIocpAsyncExecute = ^TIocpAsyncExecute;
  TIocpAsyncExecute = packed record
    Conn: TIocpConnection;
    Request: TObject;
  end;

  /// <summary>
  /// Iocp ����
  /// </summary>
  TIocpConnection = class(TIocpClientContext)
  private
    FStream: TIocpStream;
  protected
    procedure DoCleanUp; override;
    function PopMem: Pointer; inline;
    procedure PushMem(const V: Pointer); inline;

    procedure DoRecvExecute(const RequestObj: TObject);
    procedure DoJob(AJob: PIocpJob);
    procedure OnRecvBuffer(buf: Pointer; len: Cardinal; ErrorCode: Integer); override;
  public
    constructor Create(AOwner: TIocpCustom); override;
    destructor Destroy; override;  

    /// <summary>
    /// ���ݻ�����
    /// </summary>
    property BufferStream: TIocpStream read FStream;
  end;

  /// <summary>
  /// TCP ����ˣ�֧��ͨ�� OnDecodeData �¼��������ݻ�����
  /// </summary>
  {$IFDEF SupportEx}[ComponentPlatformsAttribute(SupportCurrentPlatforms)]{$ENDIF}
  TIocpTcpCodecServer = class(TIocpTcpServer)
  private
    FMemPool: TIocpMemPool;
    FIocpStreamPool: TBaseQueue;
    FOnRecvExecute: TOnRecvExecute;
    FOnDecodeData: TOnDecodeData;
    FAsyncExecute: Boolean;
  protected
    function GetStream: TIocpStream;
    procedure FreeStream(V: TIocpStream);
    function DoDecodeData(Connection: TIocpConnection; Stream: TIocpStream;
      var Request: TObject): Boolean; 
    procedure DoRecvExecute(const AConnection: TIocpConnection;
      var RequestObj: TObject; const ATaskWorker: TIocpTaskWorker); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function PopMem: Pointer;
    procedure PushMem(const V: Pointer);
  published
    /// <summary>
    /// �Ƿ��첽ִ�����������ΪFalse����ô�����õ�ǰ�����̴߳���ҵ��Ĭ���첽��
    /// </summary>
    property AsyncExecute: Boolean read FAsyncExecute write FAsyncExecute default True;
    /// <summary>
    /// ÿ�γɹ������ִ��
    /// </summary>
    property OnRecvExecute: TOnRecvExecute read FOnRecvExecute write FOnRecvExecute;
    /// <summary>
    /// ����ص��¼����ڽ��յ�����ʱ����
    /// </summary>
    property OnDecodeData: TOnDecodeData read FOnDecodeData write FOnDecodeData;
  end;

{$IFDEF UseHttpServer}
type
  TIocpHttpMethod = iocp.Http.TIocpHttpMethod;
  TIocpHttpReqVer = iocp.Http.TIocpHttpReqVer;

  TIocpHttpServer = iocp.Http.TIocpHttpServer;
  TIocpHttpsServer = iocp.Http.TIocpHttpsServer;
  TIocpHttpRequest = iocp.Http.TIocpHttpRequest;
  TIocpHttpResponse = iocp.Http.TIocpHttpResponse;
  TIocpHttpWriter = iocp.Http.TIocpHttpWriter;
  TIocpHttpCharset = iocp.Http.TIocpHttpCharset;

  TOnHttpFilter = iocp.Http.TOnHttpFilter;
  TOnHttpRequest = iocp.Http.TOnHttpRequest;
  TOnHttpGetSession = iocp.Http.TOnHttpGetSession;
  TOnHttpFreeSession = iocp.Http.TOnHttpFreeSession;

  TIocpHttpConnection = iocp.Http.TIocpHttpConnection;
  TIocpHttpSSLConnection = iocp.Http.TIocpHttpSSLConnection;
  TIocpHttpFromDataItem = iocp.Http.TIocpHttpFromDataItem;
  TFileOnlyStream = iocp.Http.TFileOnlyStream;
  TIocpPointerStream = iocp.Http.TIocpPointerStream;
{$ENDIF}

{$IFDEF UseWebSocketServer}
type
  TIocpWebSocketServer = iocp.Http.WebSocket.TIocpWebSocketServer;
  TIocpWebSocketConnection = iocp.Http.WebSocket.TIocpWebSocketConnection;
  TIocpWebSocketRequest = iocp.Http.WebSocket.TIocpWebSocketRequest;
  TIocpWebSocketResponse = iocp.Http.WebSocket.TIocpWebSocketResponse;

  TIocpWebSocketFrame = iocp.Http.WebSocket.TIocpWebSocketDataFrame;
  TIocpWebSocketOpcode = iocp.Http.WebSocket.TIocpWebSocketOpcode;

  TIocpWebSocketHttpRequest = iocp.Http.WebSocket.TIocpWebSocketHttpRequest;
  TIocpWebSocketHttpResponse = iocp.Http.WebSocket.TIocpWebSocketHttpResponse;
  
  TOnWebSocketConnection = iocp.Http.WebSocket.TOnWebSocketConnection;
  TOnWebSocketDisconnect = iocp.Http.WebSocket.TOnWebSocketDisconnect;
  TOnWebSocketRecvBuffer = iocp.Http.WebSocket.TOnWebSocketRecvBuffer;
  TOnWebSocketRequest = iocp.Http.WebSocket.TOnWebSocketRequest;
{$ENDIF}

{$IFDEF UseWebMvcServer}
type
  TIocpHttpMvcServer = iocp.Http.MVC.TIocpHttpMvcServer;
{$ENDIF}

type
  /// <summary>
  /// ������ TCP Scoket ��
  /// </summary>
  {$IFDEF SupportEx}[ComponentPlatformsAttribute(SupportCurrentPlatforms)]{$ENDIF}
  TIocpTcpSocketPool = class(TObject)
  private
    FList: TStringHash;
    FMax: Integer;
    FDestroying: Boolean;
    FLocker: TCriticalSection;
    function GetKey(const RemoteAddr: string; RemotePort: Word): string;
  protected
    function GetQueues(const Key: string): TBaseQueue; overload;
    function GetQueues(const RemoteAddr: string; RemotePort: Word): TBaseQueue; overload;
    procedure DoFreeItem(Item: PHashItem);
  public
    constructor Create(const AMax: Integer = 8);
    destructor Destroy; override;
    procedure Clear;
    /// <summary>
    /// ����һ���Ѿ�Socket���Ѿ��趨��Զ�̵�ַ�Ͷ˿ڣ�������Socket�����Ѿ�����
    /// </summary>
    function Pop(const RemoteAddr: string; RemotePort: Word): TIocpTcpSocket;
    /// <summary>
    /// ѹ��ʹ�����Socket�� Push����ȥ�������Ƿ�Ͽ�
    /// </summary>
    procedure Push(const Socket: TIocpTcpSocket);
    // ÿ������+�˿���ౣ�ֵ������� (Ĭ��8), ��Ϊ<1ʱ������������
    property Max: Integer read FMax write FMax default 8;
  end;

type
  /// <summary>
  /// TCP �ͻ��˴������
  /// </summary>
  TIocpTcpClientProxy = class;

  TIocpTcpProxyCallBack = procedure (Socket: TIocpTcpSocket; Tag: Integer) of Object;

  PIocpTcpProxyData = ^TIocpTcpProxyData;
  TIocpTcpProxyData = record
    Socket: TIocpTcpSocket;
    StartTime: Int64;
    Tag: Integer;
    IsTimeOut: Boolean;
    CallBack: TIocpTcpProxyCallBack;
    Prev: PIocpTcpProxyData;
    Next: PIocpTcpProxyData;
  end;

  TIocpTcpProxyWorkerThread = class(TThread)
  private
    FOwner: TIocpTcpClientProxy;
  protected
    procedure Execute; override;
  end;

  // Proxy �ڲ�ʹ��һ��˫���������������������ӣ� �ڶ��ߡ�
  // ��ʱ�����յ�����ʱ�ᴥ��CallBack, CallBack �������պʹ������ݣ����Բ�
  // ���� CallBack�� �������յ�����ʱ��Proxy����ս��ջ������������������
  // ��������ɾ����
  // Proxy �ڲ��ᴴ��һ�������̣߳����ϵ�ɨ����������Ƿ������ݵ��
  // ���߳��ֶ��ߡ���ʱ���������ʱ����CallBack���������ӽ��ջ�������
  {$IFDEF SupportEx}[ComponentPlatformsAttribute(SupportCurrentPlatforms)]{$ENDIF}
  TIocpTcpClientProxy = class(TObject)
  private
    FPool: TIocpTcpSocketPool;
    FMemPool: TMemPool;
    FHostSelect: TStringHash;
    FList: PIocpTcpProxyData;
    FLast: PIocpTcpProxyData;
    FWorker: array of TIocpTcpProxyWorkerThread;
    FOnStateMsg: TOnStateMsgEvent;
    FIsDestroying: Boolean;
    FTimeOut: Integer;
    function GetIsDestroying: Boolean;
  protected
    FLocker: TCriticalSection;
    procedure DoWorker();
    procedure DoStateMsg(Sender: TObject; MsgType: TIocpStateMsgType; const Msg: string);
    function CheckHost(const Host: string; const Port: Word): Boolean;
    procedure AddItem(const Socket: TIocpTcpSocket;
      const CallBack: TIocpTcpProxyCallBack; const Tag: Integer);
    function PopItem(): PIocpTcpProxyData;
    procedure PushItem(const V: PIocpTcpProxyData);
    function ItemEmpty: Boolean;
    function DoCallBack(Socket: TIocpTcpSocket;
      CallBack: TIocpTcpProxyCallBack; const Tag: Integer): Boolean;

  public
    constructor Create(AMaxWorker: Integer = 1);
    destructor Destroy; override;
    procedure Clear; virtual;

    // ����һ����","�ָ���IP�ַ����б��Զ�����IP��ַ����

    // ����һ����","�ָ���IP�ַ����б����ص�ǰʹ�õ�IP��ַ
    function HostSelect(const Host: string): string; virtual;
    // ����һ����","�ָ���IP�ַ����б��л���ǰʹ�õ�IP��ַ���л��ɹ�����True
    // �л�ʧ�ܿ����Ǳ���ٶ�̫�죬����HostΪ��
    function HostChange(const Host: string): Boolean; virtual;
    // HostChange������IPʱ�����ô˷�������ֹ�����̵߳��л�����
    procedure HostUpdate(const Host: string); overload;
    // HostChange������IPʱ�����ô˷�������ֹ�����̵߳��л�����
    procedure HostUpdate(const Host, IPAddr: string); overload;

    function GetSocket(const Host: string; const Port: Word): TIocpTcpSocket;
    procedure ReleaseSocket(V: TIocpTcpSocket); inline;
    
    function Pop(const RemoteAddr: string; RemotePort: Word): TIocpTcpSocket;
    procedure Push(const Socket: TIocpTcpSocket);

    /// <summary>
    /// �������ݵ�ָ��Զ�������˿ڡ�
    /// <param name="CallBack">�ص�����������Trueʱһ���ᱻִ�е�</param>
    /// <param name="Sync">�Ƿ�ʹ��ͬ�����ͣ�ΪTrueʱֱ�ӵ���CallBack</param>
    /// </summary>
    function Send(const Host: string; Port: Word; S: TStream;
      CallBack: TIocpTcpProxyCallBack = nil; Sync: Boolean = False; Tag: Integer = 0): Boolean; overload;
    function Send(const Host: string; Port: Word; Data: PAnsiChar;
      Len: Cardinal; CallBack: TIocpTcpProxyCallBack = nil; Sync: Boolean = False; Tag: Integer = 0): Boolean; overload;
    function Send(const Host: string; Port: Word; const Data: AnsiString;
      CallBack: TIocpTcpProxyCallBack = nil; Sync: Boolean = False; Tag: Integer = 0): Boolean; overload;
    function Send(const Host: string; Port: Word; const Data: WideString;
      CallBack: TIocpTcpProxyCallBack = nil; Sync: Boolean = False; Tag: Integer = 0): Boolean; overload;

    property OnStateInfo: TOnStateMsgEvent read FOnStateMsg write FOnStateMsg;
    // ���ճ�ʱ���ã� С��1ʱ���жϳ�ʱ��Ĭ��20��
    property TimeOut: Integer read FTimeOut write FTimeOut;
    // �Ƿ������ͷ�
    property IsDestroying: Boolean read GetIsDestroying;
  end;

{
 һЩ���ú���
}

// ��ȡCPUʹ����
function GetCPUUsage: Integer;
// ��ȡ������������
function GetTaskWorkerCount: Integer;
// ��ȡ���������������
function GetTaskWorkerMaxCount: Integer;
// ��ȡָ�����̵��ڴ�ʹ�����
function GetProcessMemUse(PID: Cardinal): Cardinal;
// ��ȡָ�����̾������
function GetProcessHandleCount(PID: Cardinal): Cardinal;
// ��ȡָ�������߳�����
function GetThreadCount(PID: THandle): Integer;

// ��ȡ��ǰʱ��� ���߾��ȼ�ʱ��
function GetTimestamp: Int64;
// ��ȡ�ļ����д��ʱ�䣨���޸�ʱ�䣩
function GetFileLastWriteTime(const AFileName: AnsiString): TDateTime;

// ��һ�������ļ���С������ת���ɿɶ����ַ���
function TransByteSize(const pvByte: Int64): string;
// ��һ�������ڴ��С������ת���ɿɶ����ַ���
function RollupSize(ASize: Int64): string;
// ��ȡ��ǰ������Ϣ
function GetRunTimeInfo: string;
// ��������ʱ��
procedure ResetRunTime;

implementation

var
  Workers: TIocpTask;
  SMemPool: TIocpMemPool;

function GetTimestamp: Int64;
begin
  Result := iocp.Core.Engine.GetTimestamp;
end;

function GetFileLastWriteTime(const AFileName: AnsiString): TDateTime;
begin
  Result := iocp.Sockets.Utils.GetFileLastWriteTime(AFileName);
end;

function GetCPUUsage: Integer;
begin
  Result := TIocpTask.GetCPUUsage;
end;

function GetTaskWorkerCount: Integer;
begin
  Result := Workers.WorkerCount;
end;

function GetTaskWorkerMaxCount: Integer;
begin
  Result := Workers.MaxWorkers;
end;

function GetProcessMemUse(PID: Cardinal): Cardinal;
begin
  Result := iocp.Winapi.TlHelp32.GetProcessMemUse(PID);
end;  

function GetProcessHandleCount(PID: Cardinal): Cardinal;
begin
  Result := iocp.Winapi.TlHelp32.GetProcessHandleCount(PID);
end;

function GetThreadCount(PID: THandle): Integer;
begin
  Result := iocp.Winapi.TlHelp32.GetThreadCount(PID);
end;

function TransByteSize(const pvByte: Int64): string;
begin
  Result := iocp.Sockets.TransByteSize(pvByte);
end;

function GetRunTimeInfo: string;
begin
  Result := iocp.Sockets.GetRunTimeInfo;
end;

procedure ResetRunTime;
begin
  iocp.Sockets.ResetRunTime;
end;

function RollupSize(ASize: Int64): string;
const
  Units: array [0 .. 3] of String = ('GB', 'MB', 'KB', 'B');
var
  AIdx: Integer;
  R1, S1: Int64;
  AIsNeg: Boolean;
begin
  AIdx := 3;
  R1 := 0;
  AIsNeg := (ASize < 0);
  if AIsNeg then
    ASize := -ASize;
  SetLength(Result, 0);
  while (AIdx >= 0) do begin
    S1 := ASize mod 1024;
    ASize := ASize shr 10;
    if (ASize = 0) or (AIdx = 0) then begin
      R1 := R1 * 100 div 1024;
      if R1 > 0 then begin
        if R1 >= 10 then
          Result := IntToStr(S1) + '.' + IntToStr(R1) + Units[AIdx]
        else
          Result := IntToStr(S1) + '.' + '0' + IntToStr(R1) + Units[AIdx];
      end else
        Result := IntToStr(S1) + Units[AIdx];
      break;
    end;
    R1 := S1;
    Dec(AIdx);
  end;
  if AIsNeg then
    Result := '-' + Result;
end;

{ TIocpConnection }

constructor TIocpConnection.Create(AOwner: TIocpCustom);
begin
  inherited Create(AOwner);
  FStream := nil;
end;

destructor TIocpConnection.Destroy;
begin
  if Assigned(Workers) and TIocpTcpCodecServer(Owner).FAsyncExecute then
    Workers.Clear(Self);
  if Assigned(Owner) and (Assigned(FStream)) then
    TIocpTcpCodecServer(Owner).FreeStream(FStream);
  FStream := nil;
  inherited Destroy;
end;

procedure TIocpConnection.DoCleanUp;
begin
  inherited DoCleanUp;
  TIocpTcpCodecServer(Owner).FreeStream(FStream);
  FStream := nil;
end;

procedure TIocpConnection.DoJob(AJob: PIocpJob);
var
  Data: TIocpAsyncExecute;
begin
  Data := PIocpAsyncExecute(AJob.Data)^;
  SMemPool.Push(AJob.Data);
  try
    // �����Ѿ��Ͽ�, ���������߼�
    if (Self = nil) or (Owner = nil) or (not Self.Active) then
      Exit;
    // �Ѿ����ǵ�ʱ��������ӣ����������߼�
    if (Data.Conn = nil) or (Data.Conn.Handle <> Self.Handle) then Exit;
    // ��������
    try
      TIocpTcpCodecServer(Owner).DoRecvExecute(Data.Conn, Data.Request, AJob.Worker);
      LastActivity := GetTimestamp;
    except
      Owner.DoStateMsgE(Self, Exception(ExceptObject));
    end;

  finally
    FreeAndNil(Data.Request);
    Self.UnLockContext(Self, 'DoRecvExecute');
  end;
end;

procedure TIocpConnection.DoRecvExecute(const RequestObj: TObject);
var
  Data: PIocpAsyncExecute;
  Request: TObject;
begin
  if Assigned(Workers) and Active then begin
    if TIocpTcpCodecServer(Owner).FAsyncExecute then begin
      if LockContext(Self, 'DoRecvExecute') then begin
        Data := SMemPool.Pop;
        Data.Conn := Self;
        Data.Request := RequestObj;
        Workers.Post(DoJob, Data);
      end else if Assigned(RequestObj) then               
        RequestObj.Free;
    end else begin
      Request := RequestObj;
      try
        TIocpTcpCodecServer(Owner).DoRecvExecute(Self, Request, nil);
        LastActivity := GetTimestamp;
      except
        Owner.DoStateMsgE(Self, Exception(ExceptObject));
      end;
      FreeAndNil(Request);
    end;
  end;
end;

procedure TIocpConnection.OnRecvBuffer(buf: Pointer; len: Cardinal;
  ErrorCode: Integer);
var
  Last: Int64;
  FRequest: TObject;
begin
  if (not Assigned(Owner)) then begin
    CloseConnection;
    Exit;
  end;
  // û�н�����ʱ��Ϊ��ͨ��TCP������
  if (not Assigned(TIocpTcpCodecServer(Owner).FOnDecodeData)) then begin
    if (not Assigned(Owner.OnDataReceived)) then
      CloseConnection;
    Exit;
  end;

  // ��ȡһ��������
  if not Assigned(FStream) then begin
    FStream := TIocpTcpCodecServer(Owner).GetStream;
    FStream.Handle := Self.Handle;
    FStream.SetCunkSize(TIocpTcpCodecServer(Owner).RecvBufferSize);
    FStream.OnPopMem := TIocpTcpCodecServer(Owner).PopMem;
    FStream.OnPushMem := TIocpTcpCodecServer(Owner).PushMem;
  end;

  // ���½��յ������ݽ��뻺����
  FStream.Write(Buf^, Len);
  FRequest := nil;
  
  // ���Խ���
  while Assigned(FStream) do begin
    FStream.WaitRecv := False;
    Last := FStream.GetPosition;

    if not TIocpTcpCodecServer(Owner).DoDecodeData(Self, FStream, FRequest) then begin
      // ����ʧ�ܣ���������ڵȴ��������ݣ���ر�����
      if not FStream.WaitRecv then        
        CloseConnection;
      Exit;
    end;

    // �ȴ���������
    if FStream.WaitRecv then
      Exit;

    if FStream.GetPosition() = Last then
      Break;

    // ����ɹ�
    DoRecvExecute(FRequest);
    
    // ��������
    if Assigned(FStream) and (FStream.GetPosition < FStream.Size) then begin
      FStream.ClearRead;
      Continue;
    end else
      Break;
  end;
  
  if Assigned(FStream) then   
    FStream.Clear;
end;

function TIocpConnection.PopMem: Pointer;
begin
  Result := TIocpTcpCodecServer(Owner).PopMem;
end;

procedure TIocpConnection.PushMem(const V: Pointer);
begin
  TIocpTcpCodecServer(Owner).PushMem(V);
end;

{ TIocpTcpCodecServer }

constructor TIocpTcpCodecServer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAsyncExecute := True;
  FIocpStreamPool := TBaseQueue.Create;
  FContextClass := TIocpConnection;
  FMemPool := TIocpMemPool.Create(RecvBufferSize, 4096);
end;

destructor TIocpTcpCodecServer.Destroy;
begin
  try
    FOnDecodeData := nil;
    inherited Destroy;
  except end;
  if Assigned(FIocpStreamPool) then begin
    FIocpStreamPool.FreeDataObject;
    FIocpStreamPool.Clear;
    FIocpStreamPool.Free;
  end;
  FreeAndNil(FMemPool);
end;

function TIocpTcpCodecServer.DoDecodeData(Connection: TIocpConnection; Stream: TIocpStream; var Request: TObject): Boolean;
begin
  if Assigned(FOnDecodeData) then
    Result := FOnDecodeData(Connection, Stream, Request)
  else
    Result := False;
end;

procedure TIocpTcpCodecServer.DoRecvExecute(const AConnection: TIocpConnection;
  var RequestObj: TObject; const ATaskWorker: TIocpTaskWorker);
begin
  if Assigned(FOnRecvExecute) and Assigned(RequestObj) then begin
    try
      {$IFDEF DEBUG_ON}
      DoStateMsgD(Self, 'DoRecvExecute: ' + RequestObj.ClassName);
      {$ENDIF}
      FOnRecvExecute(Self, AConnection, RequestObj);
    except
      DoStateMsgE(Self, 'TcpServerEx.DoRecvExecute: %s', Exception(ExceptObject));
    end;
  end;
  FreeAndNil(RequestObj);
end;

procedure TIocpTcpCodecServer.FreeStream(V: TIocpStream);
begin
  if not Assigned(V) then Exit;
  V.Clear;
  FIocpStreamPool.EnQueue(V);
end;

function TIocpTcpCodecServer.GetStream: TIocpStream;
begin
  Result := TIocpStream(FIocpStreamPool.DeQueue);
  if not Assigned(Result) then
    Result := TIocpStream.Create()
end;

function TIocpTcpCodecServer.PopMem: Pointer;
begin
  Result := FMemPool.Pop;
end;

procedure TIocpTcpCodecServer.PushMem(const V: Pointer);
begin
  FMemPool.Push(V);
end;

{ TIocpTcpSocketPool }

procedure TIocpTcpSocketPool.Clear;
begin
  FLocker.Enter;
  FList.Clear;
  FLocker.Leave;
end;

constructor TIocpTcpSocketPool.Create(const AMax: Integer);
begin
  FList := TStringHash.Create();
  FList.OnFreeItem := DoFreeItem;
  FLocker := TCriticalSection.Create;
  FMax := AMax;
end;

destructor TIocpTcpSocketPool.Destroy;
begin
  FDestroying := True;
  FreeAndNil(FList);
  FreeAndNil(FLocker);
  inherited;
end;

procedure TIocpTcpSocketPool.DoFreeItem(Item: PHashItem);
var
  Que: TBaseQueue;
begin
  Que := TBaseQueue(Pointer(Item.Value)); 
  if Assigned(Que) then begin
    Que.FreeDataObject;
    FreeAndNil(Que);
    Item.Value := 0;  
  end;
end;

function TIocpTcpSocketPool.GetKey(const RemoteAddr: string; RemotePort: Word): string;
begin
  Result := Format('%.4x.%s', [RemotePort, RemoteAddr])
end;

function TIocpTcpSocketPool.GetQueues(const RemoteAddr: string; RemotePort: Word): TBaseQueue;
begin
  if (Length(RemoteAddr) > 0) and (RemotePort > 0) then
    Result := GetQueues(GetKey(RemoteAddr, RemotePort))
  else
    Result := nil;
end;

function TIocpTcpSocketPool.GetQueues(const Key: string): TBaseQueue;
var
  V: Integer;
begin
  Result := nil;
  if Length(Key) > 0 then begin
    FLocker.Enter;
    V := FList.ValueOf(Key);
    if V > 1 then     
      Result := TBaseQueue(V);
    if not Assigned(Result) then begin
      Result := TBaseQueue.Create;
      FList.Add(Key, Integer(Result));     
    end;
    FLocker.Leave;
  end;
end;

function TIocpTcpSocketPool.Pop(const RemoteAddr: string; RemotePort: Word): TIocpTcpSocket;
var
  Que: TBaseQueue;
begin
  Que := GetQueues(RemoteAddr, RemotePort);
  if Assigned(Que) then begin
    Result := TIocpTcpSocket(Que.DeQueue);
    if not Assigned(Result) then begin
      Result := TIocpTcpSocket.Create(nil);
      Result.RemoteHost := AnsiString(RemoteAddr);
      Result.RemotePort := RemotePort;
      Result.ConnectTimeOut := 3000;
    end;
  end else 
    Result := TIocpTcpSocket.Create(nil);
end;

procedure TIocpTcpSocketPool.Push(const Socket: TIocpTcpSocket);
var
  Que: TBaseQueue;
begin
  if (not Assigned(Socket)) or (not Assigned(Self)) then Exit;
  Que := GetQueues(string(Socket.RemoteHost), Socket.RemotePort);
  if Assigned(Que) and ((FMax < 1) or (Que.Size < FMax)) then begin
    Que.EnQueue(Socket);
  end else
    Socket.Free;
end;

{ TIocpTcpClientProxy }

const
  IPIndexHeader = 'ipi_';
  IPLastHeader = 'ipl_';
  IPLastTimeHeader = 'ipt_';
  IPChangeOK = 9999999;

procedure TIocpTcpClientProxy.AddItem(const Socket: TIocpTcpSocket;
  const CallBack: TIocpTcpProxyCallBack; const Tag: Integer);
var
  Item: PIocpTcpProxyData;
  Time: Int64;
begin
  Time := GetTimestamp;
  FLocker.Enter;
  Item := FMemPool.Pop;
  Item.Socket := Socket;
  Item.Tag := Tag;
  Item.StartTime := Time;
  Item.CallBack := CallBack;
  Item.Next := nil;
  if FLast = nil then begin
    FList := Item;
    Item.Prev := nil;
  end else begin
    Item.Prev := FLast;
    FLast.Next := Item;
  end;
  FLast := Item;
  FLocker.Leave; 
end;

function TIocpTcpClientProxy.HostChange(const Host: string): Boolean;
var
  I: Integer;
  T: Cardinal;
  List: TStrings;
begin
  Result := False;
  List := TStringList.Create;
  try
    List.Delimiter := ',';
    List.DelimitedText := Host;
    if List.Count < 2 then Exit;
    T := FHostSelect.ValueOf(IPLastTimeHeader + Host);
    if Abs(GetTickCount - T) > 300000 then begin   // 30����û�и��Ĺ���ַ����ӵ�һ����ʼ
      I := 0;
    end else begin
      I := FHostSelect.ValueOf(IPLastHeader + Host);
      if I < 0 then I := 0;
    end;

    // �������߳��Ѿ��л��ɹ���
    if I = IPChangeOK then begin
      Result := True;
      Exit;
    end;
    
    if I >= List.Count then Exit;
    Inc(I);
    FHostSelect.Add(IPLastTimeHeader + Host, GetTickCount);
    FHostSelect.Add(IPLastHeader + Host, I);

    I := FHostSelect.ValueOf(IPIndexHeader + Host) + 1;
    if (I < 0) or (I >= List.Count) then
      I := 0;
    FHostSelect.Add(Host, ipToInt(AnsiString(List[I])));
    FHostSelect.Add(IPIndexHeader + Host, I);
    Result := True;
  finally
    List.Free;
  end;
end;

function TIocpTcpClientProxy.HostSelect(const Host: string): string;
var
  I: Cardinal;
  L: Integer;
begin
  // �Ӷ��IP��ѡ��һ�����õ�
  if Length(Host) = 0 then
    Result := ''
  else begin
    I := FHostSelect.ValueOf(Host);
    if I <> 0 then
      Result := IPToStr(I)
    else begin
      L := Pos(',', Host);
      if L = 0 then
        Result := Host
      else
        Result := Copy(Host, 1, L - 1);
      FHostSelect.Add(Host, ipToInt(AnsiString(Result)));
    end;
  end;
end;

procedure TIocpTcpClientProxy.HostUpdate(const Host: string);
begin
  FHostSelect.Add(IPLastHeader + Host, IPChangeOK);
end;

procedure TIocpTcpClientProxy.HostUpdate(const Host, IPAddr: string);
begin
  FHostSelect.Add(Host, ipToInt(AnsiString(IPAddr)));
  HostUpdate(Host);
end;

function TIocpTcpClientProxy.CheckHost(const Host: string;
  const Port: Word): Boolean;
begin
  Result := (Port > 0) and (Length(Host) > 0);
end;

procedure TIocpTcpClientProxy.Clear;
var
  P, P1: PIocpTcpProxyData;
begin
  FLocker.Enter;
  P := FList;
  while P <> nil do begin
    P1 := P;
    P := P.Next;
    if Assigned(P1.CallBack) then begin
      try
        P1.CallBack(P1.Socket, P1.Tag);
      except
        DoStateMsg(Self, iocp_mt_Error, Exception(ExceptObject).Message);
      end;
    end;
    ReleaseSocket(P1.Socket);
    FMemPool.Push(P1);
  end;
  FLocker.Leave;
end;

constructor TIocpTcpClientProxy.Create(AMaxWorker: Integer);
var
  I: Integer;
begin
  FTimeOut := 30000;
  FHostSelect := TStringHash.Create();
  FPool := TIocpTcpSocketPool.Create(64);
  FMemPool := TMemPool.Create(SizeOf(TIocpTcpProxyData));
  FLocker := TCriticalSection.Create;
  if AMaxWorker < 1 then AMaxWorker := 1;
  if AMaxWorker > 64 then AMaxWorker := 64;  
  SetLength(FWorker, AMaxWorker);
  for I := 0 to AMaxWorker - 1 do begin
    FWorker[I] := TIocpTcpProxyWorkerThread.Create(True);
    FWorker[I].FOwner := Self;
    {$IFDEF UNICODE}
    FWorker[I].Start;
    {$ELSE}
    FWorker[I].Resume;
    {$ENDIF}
  end;
end;

destructor TIocpTcpClientProxy.Destroy;
var
  I: Integer;
begin
  FIsDestroying := True;
  try
    Clear;
  finally
    FreeAndNil(FPool);
    FreeAndNil(FMemPool);
    FreeAndNil(FLocker);
    FreeAndNil(FHostSelect);
    for I := 0 to High(FWorker) do
      FreeAndNil(FWorker[I]);
    inherited Destroy;
  end;
end;

function TIocpTcpClientProxy.DoCallBack(Socket: TIocpTcpSocket;
  CallBack: TIocpTcpProxyCallBack; const Tag: Integer): Boolean;
begin
  try
    if Assigned(CallBack) then begin
      CallBack(Socket, Tag);
    end else
      Socket.Disconnect;
    Result := True;
  except
    Result := False;
    DoStateMsg(Self, iocp_mt_Error, Exception(ExceptObject).Message);
  end;
end;

procedure TIocpTcpClientProxy.DoStateMsg(Sender: TObject;
  MsgType: TIocpStateMsgType; const Msg: string);
begin
  if Assigned(FOnStateMsg) then
    FOnStateMsg(Sender, MsgType, Msg);
end;

procedure TIocpTcpClientProxy.DoWorker();
var
  CallBack: TIocpTcpProxyCallBack;
  Item: PIocpTcpProxyData;
  IsFree: Boolean;
  IsBreak: Boolean;
  Time: Int64;
  List: TList;
  I: Integer;
begin
  if ItemEmpty then Exit;  
  List := TList.Create;
  try
    while not IsDestroying do begin
      Time := GetTimestamp;
      Item := PopItem;
      CallBack := nil;
      if Item <> nil then begin
        IsBreak := Item.Next = nil;
        IsFree := False;
        if Assigned(Item.Socket) then begin
          if not Item.Socket.RecvBufferIsEmpty then begin // ������ݽ���
            CallBack := Item.CallBack;
            Item.CallBack := nil;
            DoCallBack(Item.Socket, CallBack, Item.Tag);
            IsFree := True;
          end else if not Item.Socket.Active then  // ���ӶϿ�
            IsFree := True
          else if (FTimeOut > 0) and (Time - Item.StartTime > FTimeOut) then begin // ��ʱ
            IsFree := True;
            Item.IsTimeOut := True;
            Item.Socket.Disconnect;
          end;
        end else
          IsFree := True;
        if IsFree then begin  // ��ʱ���Ͽ������ʱ�ͷ�����
          try
            if Assigned(Item.CallBack) then begin
              try  // �����δ���ù�CallBack�򴥷�
                Item.CallBack(Item.Socket, Item.Tag);
              except
                DoStateMsg(Self, iocp_mt_Error, Exception(ExceptObject).Message);
              end;
            end;
          finally
            ReleaseSocket(Item.Socket);
            Item.Socket := nil;
            Item.CallBack := nil;
            FLocker.Enter;
            FMemPool.Push(Item);
            FLocker.Leave;
          end;
        end else
          List.Add(Item);
        if IsBreak then
          Break;
      end else
        Break;
      ThreadYield;
    end;
  finally
    ThreadYield;
    for I := 0 to List.Count - 1 do
      PushItem(List[I]);
    FreeAndNil(List);
  end;
end;

function TIocpTcpClientProxy.GetIsDestroying: Boolean;
begin
  Result := (not Assigned(Self)) or FIsDestroying;
end;

function TIocpTcpClientProxy.GetSocket(const Host: string;
  const Port: Word): TIocpTcpSocket;
begin
  if CheckHost(Host, Port) then begin
    Result := FPool.Pop(HostSelect(Host), Port);
    if Assigned(Result) then begin
      if not Result.Connect(False) then begin
        // ����ʧ�ܣ��Զ��л�IP��·
        while HostChange(Host) do begin
          Result := FPool.Pop(HostSelect(Host), Port);
          if Assigned(Result) then begin
            if Result.Connect(False) then begin
              HostUpdate(Host);
              DoStateMsg(Self, iocp_mt_Debug, Format('�л���������%s, %s',
                [Host, Result.RemoteHost]));
              Break;
            end else begin
              FPool.Push(Result);
              Result := nil;
            end;
          end else
            Break;
        end;
      end;
    end;
  end else
    Result := nil;
end;

function TIocpTcpClientProxy.ItemEmpty: Boolean;
begin
  FLocker.Enter;
  Result := FList = nil;
  FLocker.Leave;
end;

function TIocpTcpClientProxy.Pop(const RemoteAddr: string;
  RemotePort: Word): TIocpTcpSocket;
begin
  Result := FPool.Pop(RemoteAddr, RemotePort);
end;

function TIocpTcpClientProxy.PopItem: PIocpTcpProxyData;
begin
  FLocker.Enter;
  Result := FList;
  if Result <> nil then begin
    FList := FList.Next;
    if FList <> nil then    
      FList.Prev := nil;
    if FLast = Result then
      FLast := nil;
  end else if FLast <> nil then
    FLast := nil;
  FLocker.Leave;
end;

procedure TIocpTcpClientProxy.Push(const Socket: TIocpTcpSocket);
begin
  FPool.Push(Socket);
end;

procedure TIocpTcpClientProxy.PushItem(const V: PIocpTcpProxyData);
begin
  if V = nil then Exit;
  FLocker.Enter;
  V.Next := nil;
  if FLast = nil then begin
    FList := V;
    V.Prev := nil;
  end else begin
    V.Prev := FLast;
    FLast.Next := V;
  end;
  FLast := V;
  FLocker.Leave;
end;

procedure TIocpTcpClientProxy.ReleaseSocket(V: TIocpTcpSocket);
begin
  FPool.Push(V);
end;

function TIocpTcpClientProxy.Send(const Host: string; Port: Word; S: TStream;
  CallBack: TIocpTcpProxyCallBack; Sync: Boolean; Tag: Integer): Boolean;
var
  Socket: TIocpTcpSocket;
begin
  Result := False;
  if (not Assigned(S)) or (S.Size - S.Position = 0) then Exit;  
  Socket := GetSocket(Host, Port);
  if Assigned(Socket) then begin
    try
      try
        Socket.Send(S);
      except
        if not Socket.Active then begin
          Socket.Active := True;
          Socket.Send(S);
        end else
          Exit;
      end;
      if Sync then begin
        DoCallBack(Socket, CallBack, Tag);
      end else begin
        AddItem(Socket, CallBack, Tag);
      end;
      Result := True;
    finally
      if (not Result) or Sync then
        ReleaseSocket(Socket);
    end;
  end;
end;

function TIocpTcpClientProxy.Send(const Host: string; Port: Word;
  const Data: WideString; CallBack: TIocpTcpProxyCallBack;
  Sync: Boolean; Tag: Integer): Boolean;
var
  Socket: TIocpTcpSocket;
begin
  Result := False;
  if Length(Data) = 0 then Exit;
  Socket := GetSocket(Host, Port);
  if Assigned(Socket) then begin
    try
      try
        Socket.Send(Data);
      except
        if not Socket.Active then begin
          Socket.Active := True;
          Socket.Send(Data);
        end else
          Exit;
      end;
      if Sync then begin
        DoCallBack(Socket, CallBack, Tag);
      end else begin
        AddItem(Socket, CallBack, Tag);
      end;
      Result := True;
    finally
      if (not Result) or Sync then
        ReleaseSocket(Socket);
    end;
  end;  
end;

function TIocpTcpClientProxy.Send(const Host: string; Port: Word;
  const Data: AnsiString; CallBack: TIocpTcpProxyCallBack;
  Sync: Boolean; Tag: Integer): Boolean;
var
  Socket: TIocpTcpSocket;
begin
  Result := False;
  if Length(Data) = 0 then Exit;  
  Socket := GetSocket(Host, Port);
  if Assigned(Socket) then begin
    try
      try
        Socket.Send(Data);
      except
        if not Socket.Active then begin
          Socket.Active := True;
          Socket.Send(Data);
        end else begin
          Socket.Disconnect;
          Exit;
        end;
      end;
      if Sync then begin
        DoCallBack(Socket, CallBack, Tag);
      end else begin
        AddItem(Socket, CallBack, Tag);
      end;
      Result := True;
    finally
      if (not Result) or Sync then
        ReleaseSocket(Socket);
    end;
  end;
end;

function TIocpTcpClientProxy.Send(const Host: string; Port: Word;
  Data: PAnsiChar; Len: Cardinal; CallBack: TIocpTcpProxyCallBack;
  Sync: Boolean; Tag: Integer): Boolean;
var
  Socket: TIocpTcpSocket;
begin
  Result := False;
  if (Data = nil) or (Len = 0) then Exit;
  Socket := GetSocket(Host, Port);
  if Assigned(Socket) then begin
    try
      try
        Socket.Send(Data, Len);
      except
        if not Socket.Active then begin
          Socket.Active := True;
          Socket.Send(Data, Len);
        end else
          Exit;
      end;
      if Sync then begin
        DoCallBack(Socket, CallBack, Tag);
      end else begin
        AddItem(Socket, CallBack, Tag);
      end;
      Result := True;
    finally
      if (not Result) or Sync then   
        ReleaseSocket(Socket);
    end;
  end;
end;

{ TIocpTcpProxyWorkerThread }

procedure TIocpTcpProxyWorkerThread.Execute;
begin
  while not Terminated do begin
    if Assigned(FOwner) and (not FOwner.IsDestroying) then begin
      try
        FOwner.DoWorker();
      except
        FOwner.DoStateMsg(Self, iocp_mt_Error, Exception(ExceptObject).Message);
      end;
      Sleep(100);
    end;
  end;
end;

initialization
  Workers := TIocpTask.GetInstance;
  SMemPool := TIocpMemPool.Create(8, 2048);

finalization
  Workers := nil;
  FreeAndNil(SMemPool);

end.


