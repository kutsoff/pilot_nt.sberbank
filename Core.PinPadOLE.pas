unit Core.PinPadOLE;

{
  Краткое описание функций
  Функция  SРaram
  Функция  SParam  (Name, Value) предназначена для задания входных параметров.
  Name - имя входного параметра.
  Value - значение входного параметра.
  Возвращает S_OK при удачной реализации.
  Функция  GРaramString
  Функция  GParamString(Name, Value)  предназначена для получения выходных параметров.
  Name - имя выходных параметра.
  Value - значение выходного параметра.
  Можно вызывать 2 способами:
  1.	GParamString(Name, Value)
  2.	Value =GParamString(Name)

  Возвращает значение параметра с именем Name.

  Функция  NFun
  Функция  NFun(func) предназначена для запуска определенной функции в библиотеке (после того как необходимые входные параметры будут заданы).
  Параметр func задает номер вызываемой функции. Подробное описание номеров функций библиотеки приводится в Приложении.
  Возвращает код ошибки. 0 – успешное выполнение, любое другое – ошибка.

  Функция  Clear
  Функция  Clear()  предназначена очистки списка параметров.
  Возвращает S_OK при удачной реализации.
}

interface

uses ActiveX, Windows, SysUtils, ComObj, Classes, Variants;

const
  OleName: string = 'SBRFSRV.Server';

type
  TSberFunc = (fnSuspendTran = 6003, fnCommitTran = 6001, fnRollbackTran = 6004,
    fnPayInfo = 7005, fnCardAuth = 4000, fnReturn = 4002, fnAnnulate = 4003,
    fnTestPinPad = 13, fnSberCloseDay = 6000, fnSberXReport = 6002,
    fnSberShiftAll = 7000, fnReadTrack2 = 5002, fnServiceMenu = 10);

  TPinPadOLE = class
    strict private
      FPinPad: Variant;
      FAuthCode: string;
      FCheque: string;
      FPayInfo: string;
      FAmount: UINT;
      function SParam(name, Value: string): integer;
      procedure Clear;
      function GParamString(name: string): string;
      function NFun(func: TSberFunc): integer;
    public
      constructor Create;
      destructor Destroy;
      function CardAuth7(Amount: Double; Operation: TSberFunc): integer;
      function CommitTrx: integer;
      function RollbackTrx: integer;
      function SuspendTrx: integer;
      function TestPinPad: boolean;
      procedure PinpadClear;
      function SberShift: integer;
      function CloseDay: integer;
      function Return(Amount: Double): integer;
      function ReadTrack2: string;
      function ServiceMenu: integer;
    published
      property PayInfo: string read FPayInfo write FPayInfo;
      property Cheque: string read FCheque;
      property AuthCode: string read FAuthCode;
  end;

implementation

{ TPinPadOLE }

function TPinPadOLE.CardAuth7(Amount: Double; Operation: TSberFunc): integer;
var
  Sum: UINT;
begin
  Sum := Round(Amount * 100);
  Clear;

  FAmount := Sum;
  SParam('Amount', Inttostr(Sum));

  Result := NFun(fnCardAuth);

  if (FPayInfo <> '') and (Result = 0) then
    begin
      SParam('PayInfo', FPayInfo);
      Result := NFun(fnPayInfo);
    end;

  FCheque   := GParamString('Cheque');
  FAuthCode := GParamString('AuthCode');
end;

procedure TPinPadOLE.PinpadClear;
begin
  FPinPad.Clear;
end;

procedure TPinPadOLE.Clear;
begin
  FAmount   := 0;
  FAuthCode := '';
  FCheque   := '';
  FPayInfo  := '';
  FPinPad.Clear;
end;

function TPinPadOLE.CloseDay: integer;
begin
  Clear;
  Result  := NFun(fnSberCloseDay);
  FCheque := GParamString('Cheque');
end;

function TPinPadOLE.CommitTrx: integer;
begin
  SParam('Amount', Inttostr(FAmount));
  SParam('AuthCode', FAuthCode);
  Result := NFun(fnCommitTran);
end;

constructor TPinPadOLE.Create;
begin
  CoInitializeEx(nil, COINIT_MULTITHREADED);
  inherited Create;
  if VarIsEmpty(FPinPad) then
    try
      FPinPad := CreateOLEObject(OleName);
    except
      on E: exception do;
    end;
end;

destructor TPinPadOLE.Destroy;
begin
  if not VarIsEmpty(FPinPad) then
    FPinPad := 0;
  inherited Destroy;
  CoUninitialize;
end;

function TPinPadOLE.GParamString(name: string): string;
begin
  Result := FPinPad.GParamString(name);
end;

function TPinPadOLE.NFun(func: TSberFunc): integer;
begin
  Result := FPinPad.NFun(integer(func));
end;

function TPinPadOLE.ReadTrack2: string;
begin
  if NFun(fnReadTrack2) = 0 then
    Result := GParamString('Track2') // GParamString('ClientCard')
  else
    Result := '';
end;

function TPinPadOLE.Return(Amount: Double): integer;
var
  Sum: UINT;
begin
  Sum := Round(Amount * 100);
  Clear;
  SParam('Amount', Inttostr(Sum));
  SParam('AuthCode', FAuthCode);

  Result := NFun(fnAnnulate);

  if (FPayInfo <> '') and (Result = 0) then
    begin
      SParam('PayInfo', FPayInfo);
      Result := NFun(fnPayInfo);
    end;

  FCheque := GParamString('Cheque');
end;

function TPinPadOLE.RollbackTrx: integer;
begin
  SParam('Amount', Inttostr(FAmount));
  SParam('AuthCode', FAuthCode);
  Result := NFun(fnRollbackTran);
end;

// Контрольная лента смены
function TPinPadOLE.SberShift: integer;
begin
  Clear;
  Result  := NFun(fnSberShiftAll);
  FCheque := GParamString('Cheque');
end;

function TPinPadOLE.ServiceMenu: integer;
begin
  Result := NFun(fnServiceMenu);
end;

function TPinPadOLE.SParam(name, Value: string): integer;
begin
  Result := FPinPad.SParam(name, Value);
end;

function TPinPadOLE.SuspendTrx: integer;
begin
  SParam('Amount', Inttostr(FAmount));
  SParam('AuthCode', FAuthCode);
  Result := NFun(fnSuspendTran);
end;

function TPinPadOLE.TestPinPad: boolean;
begin
  Result := NFun(fnTestPinPad) = 0;
end;

end.
