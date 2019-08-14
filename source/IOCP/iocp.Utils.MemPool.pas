{*******************************************************}
{                                                       }
{       iocp.Utils.MemPool    �ڴ��                    }
{                                                       }
{       ��Ȩ���� (C) 2013  YangYxd                      }
{                                                       }
{*******************************************************}
{
  ˵���� TIocpMemPool ��������޸ģ��������ǻ����� QDAC
  ���ߵķ�ʽ�����Ӽ�����ˡ���л QDAC���� swish��
}

unit iocp.Utils.MemPool;

interface

{$DEFINE UseMemPool_IocpLink}
{$IF defined(FPC) or defined(VER170) or defined(VER180) or defined(VER190) or defined(VER200) or defined(VER210)}
  {$DEFINE HAVE_INLINE}
{$IFEND}

uses
  {$IFDEF MSWINDOWS}Windows, {$ENDIF}
  SysUtils, Classes, SyncObjs;

{$if CompilerVersion < 23}
type
   NativeUInt = Cardinal;
   IntPtr = Cardinal;
{$ifend}

const
  MemoryDelta = $2000; { Must be a power of 2 }
  MaxListSize = MaxInt div 16;
  MaxLineLength = 16 * 1024;
  LF = #10;
  CR = #13;
  EOL = CR + LF;

type
  MAddrList = array of Pointer;
  PMAddrList = ^MAddrList;
  Number = NativeUInt;

type
  /// <summary>
  /// �ڴ��  (���̰߳�ȫ)
  /// </summary>
  TYXDMemPool = class(TObject)
  private
    FMemory: Pointer;
    FDataBuf: MAddrList;
    FDataBufSize: Integer;
    FBufSize, FPosition: Number;
    FBlockSize: Number;
    FDebrisList: MAddrList;
    FDebrisCapacity: Number;
    function GetBufferPageCount: Number;
    procedure SetDebrisCapacity(NewCapacity: Number);
    function GetBufferSize: Number;
  protected
    FDebrisCount: Number;
    procedure ClearDebris();
    procedure GrowDebris; virtual;
  public
    constructor Create(BlockSize: Number; PageSize: Number = MemoryDelta); virtual;
    destructor Destroy; override;
    procedure Clear;
    function Pop: Pointer;
    procedure Push(const V: Pointer);
    property Size: Number read GetBufferSize;
    property BlockSize: Number read FBlockSize;
    property PageCount: Number read GetBufferPageCount;
  end;

type
  TIocpMemPoolNotify = procedure(Sender: TObject; const AData: Pointer) of object;
  TIocpMemPoolNew = procedure(Sender: TObject; var AData: Pointer) of object;

type
  /// <summary>
  /// �̶���С�ڴ�أ� �̰߳�ȫ
  ///  ע�����Push ʱ��������ѹ��������Ƿ��Ѿ�Push����
  ///  �ظ�Push�ؽ�����AV���쳣�����غ��
  /// </summary>
  TIocpMemPool = class(TObject)
  private
    FPool: MAddrList;
    FCount: Integer;
    FMaxSize: Integer;
    FBlockSize: Number;
    FLocker: TCriticalSection;
    FOnFree: TIocpMemPoolNotify;
    FOnNew: TIocpMemPoolNew;
    FOnReset: TIocpMemPoolNotify;
  protected
    procedure DoFree(const AData: Pointer); inline;
    procedure DoReset(const AData: Pointer); inline;
    procedure DoNew(var AData: Pointer); // inline;
  public
    constructor Create(BlockSize: Number; MaxSize: Integer = 64);
    destructor Destroy; override;
    procedure Clear;
    procedure Lock; {$IFDEF HAVE_INLINE} inline;{$ENDIF}
    procedure Unlock; {$IFDEF HAVE_INLINE} inline;{$ENDIF}
    function Pop(): Pointer;
    procedure Push(const V: Pointer);
    property BlockSize: Number read FBlockSize;
    property MaxSize: Integer read FMaxSize;
    property Count: Integer read FCount;
    property OnFree: TIocpMemPoolNotify read FOnFree write FOnFree;
    property OnNew: TIocpMemPoolNew read FOnNew write FOnNew;
    property OnReset: TIocpMemPoolNotify read FOnReset write FOnReset;
  end;

type
  PIocpLink = ^TIocpLink;
  TIocpLink = packed record
    Next: PIocpLink;
    Data: PAnsiChar;
  end;

type
  TOnPopMem = function (): Pointer of object;
  TOnPushMem = procedure (const V: Pointer) of object;

type
  /// <summary>
  /// IOCP ������ �����̰߳�ȫ��
  /// </summary>
  TIocpStream = class(TStream)
  private
    FHandle: Number;
    FWritePos: Pointer;
    FReadPos: PAnsiChar;
    FFirst: PIocpLink;
    FLast: PIocpLink;
    FCur: PIocpLink;
    FSize: Integer;
    FOffset: Integer;
    FPosition: Int64;
    FCunkSize: Integer;
    FWaitRecv: Boolean;
    FOnGetMem: TOnPopMem;
    FOnPushMem: TOnPushMem;
    function ReadData(const Offset: Integer): Boolean;
    function GetUnReadSize: Cardinal;
  protected
    function GetSize: Int64; override;
    procedure SetSize(NewSize: Longint); overload; override;
    procedure SetSize(const NewSize: Int64); overload; override;
    function SetPosition(const Position: Int64): NativeUInt;
  public
    constructor Create();
    destructor Destroy; override;
    procedure Clear; overload;
    procedure Clear(ASize: Integer); overload;
    procedure ClearRead;
    procedure SetCunkSize(const Value: Integer);
    function GetPosition: Int64; inline;
    function Skip(ASize: Longint): Longint;
    function Read(var Buffer; Count: Longint): Longint; override;
    function ReadLn(const ATerminator: string = ''; const AMaxLineLength: Integer = MaxLineLength): string;
    function ReadString(ASize: Integer): string;
    function ReadBuffer(var Buffer; Count: Longint): Boolean; inline;
    // д�����ݣ��û���Ҫ���ⲿ����
    function Write(const Buffer; Count: Longint): Longint; override;
    function WriteBuffer(Buf: PAnsiChar; Count: Longint): Longint; 
    function Seek(const Offset: Int64; Origin: TSeekOrigin = soCurrent): Int64; override;
    // �Ƿ���Ҫ���ո�������ݣ�
    property WaitRecv: Boolean read FWaitRecv write FWaitRecv;
    // δ�����ݴ�С
    property UnReadSize: Cardinal read GetUnReadSize;
    // �Զ�����
    property Handle: Number read FHandle write FHandle;
    property OnPopMem: TOnPopMem read FOnGetMem write FOnGetMem;
    property OnPushMem: TOnPushMem read FOnPushMem write FOnPushMem;
  end;

implementation

resourcestring
  strStreamError = '��֧�ֵĽӿ�';

{$IFDEF UseMemPool_IocpLink}
var
  SMemPool: TIocpMemPool;
{$ENDIF}
  
{ TYxdMemPool }

procedure TYxdMemPool.Clear;
var
  I: Integer;
begin
  for i := 0 to FDataBufSize do
    FreeMem(FDataBuf[i], FBufSize);
  SetLength(FDataBuf, 0);
  FMemory := nil;
  FDataBufSize := -1;
  FPosition := FBufSize;
  ClearDebris();
end;

procedure TYxdMemPool.ClearDebris;
begin
  SetDebrisCapacity(0);
  FDebrisCount := 0;
end;

constructor TYxdMemPool.Create(BlockSize, PageSize: Number);
begin
  FBlockSize := BlockSize;
  if FBlockSize < 1 then
    FBlockSize := 4;
  FBufSize := (PageSize div FBlockSize);
  if (FBufSize < 1) or (PageSize mod FBlockSize > 0) then
    Inc(FBufSize);
  FBufSize := FBufSize * FBlockSize;

  FMemory := nil;
  FDataBufSize := -1;
  FPosition := FBufSize;

  FDebrisCount := 0;
  FDebrisCapacity := 0;
  SetLength(FDebrisList, 0);
end;

destructor TYxdMemPool.Destroy;
begin
  Clear;
  SetLength(FDebrisList, 0);
  inherited Destroy;
end;

function TYxdMemPool.GetBufferPageCount: Number;
begin
  Result := Length(FDataBuf);
end;

function TYxdMemPool.GetBufferSize: Number;
begin
  if High(FDataBuf) < 0 then
    Result := 0
  else Result := Number(GetBufferPageCount) * FBufSize;
end;

procedure TYxdMemPool.GrowDebris;
var
  Delta: Number;
begin
  if FDebrisCapacity > 64 then begin
    Delta := FDebrisCapacity shr 2;
    if Delta > 1024 then
      Delta := 1024;
  end else
    if FDebrisCapacity > 8 then
      Delta := 16
    else
      Delta := 4;
  SetDebrisCapacity(FDebrisCapacity + Delta);
end;

function TYxdMemPool.Pop: Pointer;
begin
  if FDebrisCount > 0 then begin
    Dec(FDebrisCount);
    Result := FDebrisList[FDebrisCount]; // ȡĩβ�ģ������ƶ��ڴ�
    FDebrisList[FDebrisCount] := nil;
  end else begin
    if (FBufSize - FPosition < FBlockSize) then begin   // Ԥ�����ڴ��Ѿ����꣬�����ڴ�
      Inc(FDataBufSize);
      SetLength(FDataBuf, FDataBufSize + 1);
      GetMem(FMemory, FBufSize);
      FDataBuf[FDataBufSize] := FMemory;
      Result := FMemory;
      FPosition := FBlockSize;
    end else begin
      Result := Pointer(Number(FMemory) + FPosition);
      Inc(FPosition, FBlockSize);
    end;
  end;
end;

procedure TYxdMemPool.Push(const V: Pointer);
begin
  if V <> nil then begin
    if FDebrisCount = FDebrisCapacity then
      GrowDebris;
    FDebrisList[FDebrisCount] := V;
    Inc(FDebrisCount);
  end;
end;

procedure TYxdMemPool.SetDebrisCapacity(NewCapacity: Number);
begin
  if (NewCapacity < FDebrisCount) or (NewCapacity > MaxListSize) then
    Exit;
  if NewCapacity <> FDebrisCapacity then begin
    SetLength(FDebrisList, NewCapacity);
    FDebrisCapacity := NewCapacity;
  end;
end;

{ TIocpMemPool }

procedure TIocpMemPool.Clear;
var
  I: Integer;
begin
  FLocker.Enter;
  try
    I := 0;
    while I < FCount do begin
      DoFree(FPool[I]);
      Inc(I);
    end;
  finally
    FLocker.Leave;
  end;
end;

constructor TIocpMemPool.Create(BlockSize: Number; MaxSize: Integer);
begin
  FLocker := TCriticalSection.Create;
  FCount := 0;
  if MaxSize < 4 then
    FMaxSize := 4
  else
    FMaxSize := MaxSize;
  SetLength(FPool, FMaxSize);
  FBlockSize := BlockSize;
  if BlockSize <= 8 then
    FBlockSize := 8
  else if BlockSize <= 16 then
    FBlockSize := 16
  else if BlockSize <= 32 then
    FBlockSize := 32
  else begin
    // ���С��64�ֽڶ��룬������ִ��Ч�����
    if (BlockSize mod 64 = 0) then
      FBlockSize := BlockSize
    else
      FBlockSize := (BlockSize div 64) * 64 + 64;
  end; 
end;

destructor TIocpMemPool.Destroy;
begin
  try
    Clear;
  finally
    FreeAndNil(FLocker);  
    inherited;
  end;
end;

procedure TIocpMemPool.DoFree(const AData: Pointer);
begin
  if Assigned(FOnFree) then
    FOnFree(Self, AData)
  else
    FreeMem(AData);
end;

procedure TIocpMemPool.DoNew(var AData: Pointer);
begin
  if Assigned(FOnNew) then
    FOnNew(Self, AData)
  else
    GetMem(AData, FBlockSize);
end;

procedure TIocpMemPool.DoReset(const AData: Pointer);
begin
  if Assigned(FOnReset) then
    FOnReset(Self, AData);
end;

procedure TIocpMemPool.Lock;
begin
  FLocker.Enter;
end;

function TIocpMemPool.Pop: Pointer;
begin
  Result := nil;
  FLocker.Enter;
  if FCount > 0 then begin
    Dec(FCount);
    Result := FPool[FCount];
    FPool[FCount] := nil;
  end;
  FLocker.Leave;
  if Result = nil then
    DoNew(Result);
  if Result <> nil then
    DoReset(Result);
end;

procedure TIocpMemPool.Push(const V: Pointer);
var
  ADoFree: Boolean;
begin
  if V = nil then Exit;
  ADoFree := True;
  FLocker.Enter;
  if FCount < FMaxSize then begin
    FPool[FCount] := V;
    Inc(FCount);
    ADoFree := False;
  end;
  FLocker.Leave;
  if ADoFree then 
    DoFree(V);
end;

procedure TIocpMemPool.Unlock;
begin
  FLocker.Leave;
end;

{ TIocpStream }

procedure TIocpStream.Clear;
var
  Last: Pointer;
begin
  while FFirst <> nil do begin
    if Assigned(FOnPushMem) then
      FOnPushMem(FFirst.Data)
    else
      FreeMemory(FFirst.Data);
    Last := FFirst;
    FFirst := FFirst.Next;
    {$IFDEF UseMemPool_IocpLink}
    SMemPool.Push(Last);
    {$ELSE}
    Dispose(Last);
    {$ENDIF}
  end;
  FSize := 0;
  FPosition := 0;
  FOffset := 0;
  FWritePos := nil;
  FLast := nil;
  FReadPos := nil;
  FCur := nil;
  FHandle := 0;
end;

procedure TIocpStream.Clear(ASize: Integer);
var
  Last: Pointer;
begin
  if ASize < 1 then Exit;
  // ����ӿ�ʼ����ָ����С������
  if ASize >= FSize then begin
    Clear();
    Exit;
  end;
  Inc(ASize, FOffset);
  while (FFirst <> nil) and (ASize >= FCunkSize) do begin
    if Assigned(FOnPushMem) then
      FOnPushMem(FFirst.Data)
    else
      FreeMem(FFirst.Data);
    Last := FFirst;
    FFirst := FFirst.Next;
    {$IFDEF UseMemPool_IocpLink}
    SMemPool.Push(Last);
    {$ELSE}
    Dispose(Last);
    {$ENDIF}
    Dec(ASize, FCunkSize);
  end;
  FCur := FFirst;
  FPosition := 0;
  FReadPos := FCur.Data + ASize;
  FOffset := ASize;
end;

procedure TIocpStream.ClearRead;
begin
  Clear(FPosition);
end;

constructor TIocpStream.Create();
begin
  FCunkSize := 1024 shl 2;
  FSize := 0;
  FPosition := 0;
  FWritePos := nil;
  FLast := nil;
  FReadPos := nil;
  FCur := nil;
  FFirst := nil;
end;

destructor TIocpStream.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TIocpStream.GetPosition: Int64;
begin
  Result := FPosition;
end;

function TIocpStream.GetSize: Int64;
begin
  Result := FSize - FOffset;
end;

function TIocpStream.GetUnReadSize: Cardinal;
begin
  Result := FSize - FOffset - FPosition;
end;

function TIocpStream.Read(var Buffer; Count: Integer): Longint;
var
  P, P1, Buf: PAnsiChar;
  I: Integer;
begin
  Result := 0;
  if (Count < 1) or (not ReadData(Count)) then
    Exit;
  Buf := Pointer(@Buffer);
  P := FCur.Data;
  P1 := FReadPos;
  while Count > 0 do begin
    I := FCunkSize - (P1 - P);
    if I < Count then begin
      Move(P1^, Buf^, I);
      Dec(Count, I);
      Inc(Buf, I);
      FCur := FCur.Next;
      P := FCur.Data;
      P1 := P;
      Inc(Result, I);
    end else begin
      Move(P1^, Buf^, Count);
      Inc(Result, Count);
      Inc(P1, Count);
      Break;
    end;
  end;
  Inc(FPosition, Result);
  FReadPos := P1;
end;

function TIocpStream.ReadBuffer(var Buffer; Count: Integer): Boolean;
begin
  Result := Read(Buffer, Count) = Count;
end;

function TIocpStream.ReadData(const Offset: Integer): Boolean;
begin
  if (FSize - FOffset - FPosition) < OffSet then begin
    Result := False;
    FWaitRecv := True;
  end else
    Result := True;
end;

function TIocpStream.ReadLn(const ATerminator: string; const AMaxLineLength: Integer): string;

  function BinaryCmp(const p1, p2: Pointer; len: Integer): Integer;
  var
    b1, b2: PByte;
  begin
    if (len <= 0) or (p1 = p2) then
      Result := 0
    else begin
      b1 := p1;
      b2 := p2;
      Result := 0;
      while len > 0 do begin
        if b1^ <> b2^ then begin
          Result := b1^ - b2^;
          Exit;
        end;
        Inc(b1);
        Inc(b2);
      end;
    end;
  end;

  function MemScan(const S: Pointer; len_s: Integer; sub: Pointer; len_sub: Integer): Pointer;
  var
    pb_s, pb_sub, pc_sub, pc_s: PByte;
    remain: Integer;
  begin
    if len_s > len_sub then begin
      pb_s := S;
      pb_sub := sub;
      Result := nil;
      while len_s >= len_sub do begin
        if pb_s^ = pb_sub^ then begin
          remain := len_sub - 1;
          pc_sub := pb_sub;
          pc_s := pb_s;
          Inc(pc_s);
          Inc(pc_sub);
          if BinaryCmp(pc_s, pc_sub, remain) = 0 then begin
            Result := pb_s;
            Break;
          end;
        end;
        Inc(pb_s);
        Dec(len_s);
      end;
    end else if len_s = len_sub then begin
      if CompareMem(S, sub, len_s) then
        Result := S
      else
        Result := nil;
    end else
      Result := nil;
  end;

var
  P, P1: PAnsiChar;
  P2: Pointer;
  I, LResult, LTL, Count: Integer;
  LT: AnsiString;
  LCur: PIocpLink;
begin
  Count := AMaxLineLength;
  if Count < 0 then
    Count := MaxLineLength;
  if Count > Integer(UnReadSize) then
    Count := Integer(UnReadSize);
  LT := AnsiString(ATerminator);
  if LT = '' then LT := LF;

  LTL := Length(LT);
  LCur := FCur;
  P := LCur.Data;
  P1 := FReadPos;
  LResult := 0;
  P2 := nil;

  while Count > 0 do begin
    I := FCunkSize - (P1 - P);
    if I < Count then begin
      P2 := MemScan(P1, I, PAnsiChar(LT), LTL);
      if P2 <> nil then begin
        Inc(LResult, P2 - P1 + LTL);
        Break;
      end else begin
        LCur := LCur.Next;
        P := LCur.Data;
        P1 := P;
        Inc(LResult, I);
      end;
    end else begin
      P2 := MemScan(P1, Count, PAnsiChar(LT), LTL);
      if P2 <> nil then
        Inc(LResult, P2 - P1 + LTL);
      Break;
    end;
  end;

  if P2 <> nil then
    Result := ReadString(LResult)
  else begin
    FWaitRecv := True;
    Result := '';
  end;
end;

function TIocpStream.ReadString(ASize: Integer): string;
var
  LData: AnsiString;
begin
  if (ASize < 1) or (not ReadData(ASize)) then begin
    Result := '';
    Exit;
  end;
  SetLength(LData, ASize);
  Read(LData[1], ASize);
  Result := string(LData);
end;

function TIocpStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  if Origin = soBeginning then begin
    Result := SetPosition(Offset);
  end else if Origin = soEnd then
    Result := SetPosition(FSize)
  else
    Result := SetPosition(FPosition + Offset);
end;

procedure TIocpStream.SetSize(NewSize: Integer);
begin
  raise Exception.Create(strStreamError);
end;

procedure TIocpStream.SetCunkSize(const Value: Integer);
begin
  if Value < 8 then Exit;  
  FCunkSize := Value;
end;

function TIocpStream.SetPosition(const Position: Int64): NativeUInt;
var
  I: Int64;
begin
  I := Position;
  Result := FPosition;
  if Result = I then Exit;
  if I <= 0 then begin
    Result := 0;
    FCur := FFirst;
    if FCur <> nil then
      FReadPos := FCur.Data + FOffset;
  end else if I >= FSize then begin
    Result := GetSize;
    FCur := FLast;
    FReadPos := FWritePos;
  end else begin
    FCur := FFirst;
    Result := 0;
    Inc(I, FOffset);
    while (FCur <> nil) and (Result < I) do begin
      if Result + Cardinal(FCunkSize) <= I then begin
        FCur := FCur.Next;
        Inc(Result, FCunkSize);
      end else begin
        FReadPos := FCur.Data + (I - Result);
        Result := Position;
        Break;
      end;
    end;
  end;
  FPosition := Result;
end;

procedure TIocpStream.SetSize(const NewSize: Int64);
begin
  raise Exception.Create(strStreamError);
end;

function TIocpStream.Skip(ASize: Integer): Longint;
begin
  Result := SetPosition(FPosition + ASize);
end;

function TIocpStream.Write(const Buffer; Count: LongInt): Longint;
begin
  Result := WriteBuffer(Pointer(@Buffer), Count);
end;

function TIocpStream.WriteBuffer(Buf: PAnsiChar; Count: Integer): Longint;
var
  P: PAnsiChar;
  I: Integer;
begin
  Result := 0;
  if Count < 1 then
    Exit;
  if FFirst = nil then begin
    {$IFDEF UseMemPool_IocpLink}
    FFirst := SMemPool.Pop;
    {$ELSE}
    New(FFirst);
    {$ENDIF}
    FFirst.Next := nil;
    if Assigned(FOnGetMem) then
      FFirst.Data := FOnGetMem()
    else
      GetMem(FFirst.Data, FCunkSize);
    FLast := FFirst;
    FCur := FFirst;
    FWritePos := FFirst.Data;
    FReadPos := FWritePos;
  end;
  P := FLast.Data;
  while Count > 0 do begin
    I := FCunkSize - (FWritePos - P);
    if Count > I then begin
      Move(Buf^, FWritePos^, I);
      Dec(Count, I);
      Inc(Buf, I);
      {$IFDEF UseMemPool_IocpLink}
      FLast.Next := SMemPool.Pop;
      {$ELSE}
      New(FLast.Next);
      {$ENDIF}
      FLast := FLast.Next;
      FLast.Next := nil;
      if Assigned(FOnGetMem) then
        FLast.Data := FOnGetMem()
      else
        GetMem(FLast.Data, FCunkSize);
      FWritePos := FLast.Data;
      P := FWritePos;
      Inc(Result, I);
    end else begin
      Move(Buf^, FWritePos^, Count);
      FWritePos := Pointer(IntPtr(FWritePos) + NativeInt(Count));
      Inc(Result, Count);
      Break;
    end;
  end;
  Inc(FSize, Result);
end;

initialization
  {$IFDEF UseMemPool_IocpLink}
  SMemPool := TIocpMemPool.Create(8, 2048);
  {$ENDIF}

finalization
  {$IFDEF UseMemPool_IocpLink}
  FreeAndNil(SMemPool);
  {$ENDIF}

end.




