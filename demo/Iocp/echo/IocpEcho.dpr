program IocpEcho;

uses
  Forms,
  Unit1 in 'Unit1.pas' {Form1},
  uFrmSelRanage in 'uFrmSelRanage.pas' {FrmSelRanage},
  uFMMonitor in 'uFMMonitor.pas' {FMMonitor: TFrame},
  utils.buffer in '..\..\..\diocp\diocp-v5-master\source\utils.buffer.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
