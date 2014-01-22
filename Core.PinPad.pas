{ Модуль работы с пинпадом сбербанка }
{
  Порядок вызова функций библиотеки
  При оплате (возврате) покупки по банковской карте кассовая программа должна вызвать из библиотеки Сбербанка функцию card_authorize(), заполнив поля TType и Amount и указав нулевые значения в остальных полях.
  По окончании работы функции необходимо проанализировать поле RCode. Если в нем содержится значение «0» или «00», авторизация считается успешно выполненной, в противном случае – отклоненной.
  Кроме этого, необходимо проверить значение поля Check. Если оно не равно NULL, его необходимо отправить на печать (в нефискальном режиме) и затем удалить вызовом функции GlobalFree().
  В случае, если внешняя программа не обеспечивает гарантированной печати карточного чека из поля Check, она может использовать следующую логику:
  1) Выполнить функцию  card_authorize().
  2) После завершения работы функции card_authorize(), если транзакция выполнена успешно, вызвать функцию SuspendTrx() и приступить к печати чека.
  3) Если чек напечатан успешно, вызвать функцию CommitTrx().
  4) Если во время печати чека возникла неустранимая проблема, вызвать функцию RollbackTrx() для отмены платежа.
  Если в ходе печати чека произойдет зависание ККМ или сбой питания, то транзакция останется в «подвешенном» состоянии. При следующем сеансе связи с банком она автоматически отменится.

  При закрытии смены кассовая программа должна вызвать из библиотеки Сбербанка функцию close_day(), заполнив поле TType = 7 и указав нулевые значения в остальных полях.
  По окончании работы функции необходимо проверить значение поля Check. Если поле Check не равно NULL, его необходимо отправить на печать (в нефискальном режиме) и после этого удалить вызовом функции GlobaFree().
}

unit Core.PinPad;

interface

uses Classes, Windows, SysUtils;

const
  LibName: string = '.\pinpad\pilot_nt.dll';

type
  // Структура ответа
  PAuthAnswer = ^TAuthAnswer;

  TAuthAnswer = packed record
    TType: integer;
    // IN Тип транзакции (1 - Оплата, 3 - Возврат/отмена оплаты, 7 - Сверка итогов)
    Amount: UINT; // IN Сумма операции в копейках
    Rcode: array [0 .. 2] of AnsiChar;
    // OUT Результат авторизации (0 или 00 - успешная авторизация, другие значения - ошибка)
    AMessage: array [0 .. 15] of AnsiChar;
    // OUT В случае отказа в авторизации содержит краткое сообщение о причине отказа
    CType: integer;
    { OUT Тип обслуженной карты. Возможные значения:
      1 – VISA
      2 – MasterCard
      3 – Maestro
      4 – American Express
      5 – Diners Club
      6 – VISA Electron }
    Check: PAnsiChar;
    // OUT При успешной авторизации содержит образ карточного чека, который вызывающая программа должна отправить на печать, а затем освободить вызовом функции GlobalFree()
    // Может иметь значение nil. В этом случае никаких действий с ним вызывающая программа выполнять не должна.
  end;

  PAuthAnswer7 = ^TAuthAnswer7;

  TAuthAnswer7 = packed record
    AuthAnswer: TAuthAnswer;
    // вход/выход: основные параметры операции (см.выше)
    AuthCode: array [0 .. 6] of AnsiChar; // Код авторизации
    // OUT При успешной авторизации (по международной карте) содержит код авторизации. При операции по карте Сберкарт поле будет заполнено символами ‘*’.
    CardID: array [0 .. 24] of AnsiChar; // номер карты
    // OUT При успешной авторизации (по международной карте) содержит номер карты. Для международных карт все символы, кроме первых 6 и последних 4, будут заменены символами ‘*’.
    SberOwnCard: integer;
    // OUT Содержит 1, если обслуженная карта выдана Сбербанком, или 0 – в противном случае
  end;

  PAuthAnswer9 = ^TAuthAnswer9;

  TAuthAnswer9 = packed record
    AuthAnswer: TAuthAnswer;
    // вход/выход: основные параметры операции (см.выше)
    AuthCode: array [0 .. 6] of AnsiChar; // Код авторизации
    // OUT При успешной авторизации (по международной карте) содержит код авторизации. При операции по карте Сберкарт поле будет заполнено символами ‘*’.
    CardID: array [0 .. 24] of AnsiChar; // номер карты
    // OUT При успешной авторизации (по международной карте) содержит номер карты. Для международных карт все символы, кроме первых 6 и последних 4, будут заменены символами ‘*’.
    SberOwnCard: integer;
    // OUT Содержит 1, если обслуженная карта выдана Сбербанком, или 0 – в противном случае
    Hash: array [0 .. 40] of AnsiChar;
    // OUT хеш SHA1 от номера карты в формате ASCIIZ
  end;

  TOperationType = (sberPayment = 1, sberReturn = 3, sberCloseDay = 7);

  TCardAuthorize9 = function(track2: Pchar; auth_ans: PAuthAnswer9)
    : integer; cdecl;

  TCardAuthorize = function(track2: Pchar; auth_ans: PAuthAnswer)
    : integer; cdecl;

  TCardAuthorize7 = function(track2: Pchar; auth_ans: PAuthAnswer7)
    : integer; cdecl;
  {
    Функция используется для проведения авторизации по банковской карте, а также при необходимости для возврата/отмены платежа.

    Входные данные:
    track2 - Может иметь значение NULL или содержать данные 2-й дорожки карты, считанные кассовой программой
    TType	-	Тип операции: 1 – оплата, 3 –возврат/отмена оплаты.
    Amount - Сумма операции в копейках.
    Выходные параметры:
    RCode - Результат авторизации. Значения «00» или «0» означают успешную авторизацию, любые другие – отказ в авторизации.
    AMessage - В случае отказа в авторизации содержит краткое сообщение о причине отказа. Внимание: поле не имеет завершающего байта 0х00.
    CType
    Тип обслуженной карты. Возможные значения:
    1 – VISA
    2 – MasterCard
    3 – Maestro
    4 – American Express
    5 – Diners Club
    6 – VISA Electron
    Сheck
    При успешной авторизации содержит образ карточного чека, который вызывающая программа должна отправить на печать, а затем освободить вызовом функции GlobalFree().
    Может иметь значение NULL. В этом случае никаких действий с ним вызывающая программа выполнять не должна.
    AuthCode - При успешной авторизации (по международной карте) содержит код авторизации. При операции по карте Сберкарт поле будет заполнено символами ‘*’.
    CardID - При успешной авторизации (по международной карте) содержит номер карты. Для международных карт все символы, кроме первых 6 и последних 4, будут заменены символами ‘*’.
    SberOwnCard - Содержит 1, если обслуженная карта выдана Сбербанком, или 0 – в противном случае.
  }

  TTestPinPad = function(): integer; cdecl;
  {
    Функция проверяет наличие пинпада. При успешном выполнении возвращает 0 (пинпад подключен), при неудачном – код ошибки (пинпад не подключен или неисправен).
  }

  TCloseDay = function(auth_ans: PAuthAnswer): integer; cdecl;
  {
    Функция используется для ежедневного закрытия смены по картам и формирования отчетов.

    Входные параметры:
    TType - Тип операции: 7 – закрытие дня по картам.
    Amount - Не используется.
    Выходные параметры:
    Rcode - Не используется.
    AMessage - Не используется.
    CType - Не используется.
    Check - Содержит образ отчета по картам, который вызывающая программа должна отправить на печать, а затем освободить вызовом функции GlobalFree().
    Может иметь значение NULL. В этом случае никаких действий с ним вызывающая программа выполнять не должна.
  }

  TReadTrack2 = function(track2: Pchar): integer; cdecl;
  {
    Функция проверяет наличие пинпада. При успешном выполнении возвращает 0 (пинпад подключен), при неудачном – код ошибки (пинпад не подключен или неисправен).

    Track2 - Буфер, куда функция записывает прочитанную 2-ю дорожку.
  }

  // SuspendTrx
  TSuspendTrx = function(dwAmount: DWORD; pAuthCode: PAnsiString)
    : integer; cdecl;
  {
    Функция переводит последнюю успешную транзакцию в «подвешенное» состояние. Если транзакция находится в этом состоянии, то при следующем сеансе связи с банком она будет отменена.
    Входные параметры:
    dwAmount - Сумма операции (в копейках).
    pAuthCode - Код авторизации.
    Функция сверяет переданные извне параметры (сумму и код авторизации) со значениями в последней успешной операции, которая была проведена через библиотеку. Если хотя бы один параметр не совпадает, функция возвращает код ошибки 4140 и не выполняет никаких действий.
  }

  // CommitTrx
  TCommitTrx = function(dwAmount: DWORD; pAuthCode: PAnsiString)
    : integer; cdecl;
  {
    Функция возвращает последнюю успешную транзакцию в «нормальное» состояние. После этого транзакция будет включена в отчет и спроцессирована как успешная. Перевести ее снова в «подвешенное» состояние будет уже нельзя.
    Входные параметры:
    dwAmount - Сумма операции (в копейках).
    pAuthCode - Код авторизации.
    Функция сверяет переданные извне параметры (сумму и код авторизации) со значениями в последней успешной операции, которая была проведена через библиотеку. Если хотя бы один параметр не совпадает, функция возвращает код ошибки 4140 и не выполняет никаких действий.
  }

  // RollBackTrx
  TRollBackTrx = function(dwAmount: DWORD; pAuthCode: PAnsiString)
    : integer; cdecl;
  {
    Функция вызывает немедленную отмену последней успешной операции (возможно, ранее переведенную в «подвешенное» состояние, хотя это и не обязательно). Если транзакция уже была возвращена в «нормальное» состояние функцией CommitTrx(), то функция RollbackTrx() завершится с кодом ошибки 4141, не выполняя никаких действий.

    Входные параметры:
    dwAmount - Сумма операции (в копейках).
    pAuthCode - Код авторизации.
    Функция сверяет переданные извне параметры (сумму и код авторизации) со значениями в последней успешной операции, которая была проведена через библиотеку. Если хотя бы один параметр не совпадает, функция возвращает код ошибки 4140 и не выполняет никаких действий.
  }

  TPinPad = class
    strict private
      FAuthAnswer: TAuthAnswer;
      FAuthAnswer7: TAuthAnswer7;
      FAuthAnswer9: TAuthAnswer9;
      FCheque: string;
      FRCode: string;
      FMessage: string;
      FAuthCode: string;
      FTrack2: string;
    public
      constructor create;
      destructor destroy;
      function CardAuth(Summ: Currency; Operation: TOperationType): integer;
      function CardAuth7(Summ: Currency; Operation: TOperationType): integer;
      function CardAuth9(Summ: Currency; Operation: TOperationType): integer;
      function TestPinPad: boolean;
      function ReadTrack2: string;
      function CloseDay: integer;
      function SuspendTrx: integer;
      function CommitTrx: integer;
      function RollBackTrx: integer;
      property AuthAnswer: TAuthAnswer read FAuthAnswer;
      property AuthAnswer7: TAuthAnswer7 read FAuthAnswer7;
      property AuthAnswer9: TAuthAnswer9 read FAuthAnswer9;
      property Cheque: string read FCheque;
      property Rcode: string read FRCode;
      property Msg: string read FMessage;
      property track2: string read FTrack2;
      property AuthCode: string read FAuthCode;
  end;

implementation

{ TPinPad }

function TPinPad.CardAuth(Summ: Currency; Operation: TOperationType): integer;
var
  H: THandle;
  Func: TCardAuthorize;
  Sum: UINT;
begin
  Sum                := Round(Summ * 100);
  FAuthAnswer.Amount := Sum;
  FAuthAnswer.TType  := integer(Operation);
  FAuthAnswer.CType  := 0;

  H := LoadLibrary(Pchar(LibName));

  try
    @Func := GetProcAddress(H, Pchar('_card_authorize'));

    Result   := Func(Pchar(''), @FAuthAnswer);
    FCheque  := PAnsiChar(FAuthAnswer.Check);
    FRCode   := AnsiString(FAuthAnswer.Rcode);
    FMessage := AnsiString(FAuthAnswer.AMessage);
  finally
    Func := nil;
    FreeLibrary(H);
  end;
end;

function TPinPad.CardAuth7(Summ: Currency; Operation: TOperationType): integer;
var
  H: THandle;
  Func: TCardAuthorize7;
  Sum: UINT;
begin
  Sum                := Round(Summ * 100);
  FAuthAnswer.Amount := Sum;
  FAuthAnswer.TType  := integer(Operation);
  FAuthAnswer.CType  := 0;

  FAuthAnswer7.AuthAnswer := FAuthAnswer;

  H := LoadLibrary(Pchar(LibName));

  try
    @Func := GetProcAddress(H, Pchar('_card_authorize7'));

    Result := Func(Pchar(''), @FAuthAnswer7);

    FCheque   := PAnsiChar(FAuthAnswer7.AuthAnswer.Check);
    FRCode    := AnsiString(FAuthAnswer7.AuthAnswer.Rcode);
    FMessage  := AnsiString(FAuthAnswer7.AuthAnswer.AMessage);
    FAuthCode := AnsiString(FAuthAnswer7.AuthCode);
  finally
    Func := nil;
    FreeLibrary(H);
  end;
end;

function TPinPad.CardAuth9(Summ: Currency; Operation: TOperationType): integer;
var
  H: THandle;
  Func: TCardAuthorize9;
  Sum: UINT;
begin
  Sum                := Round(Summ * 100);
  FAuthAnswer.Amount := Sum;
  FAuthAnswer.TType  := integer(Operation);
  FAuthAnswer.CType  := 0;

  FAuthAnswer9.AuthAnswer := FAuthAnswer;

  H := LoadLibrary(Pchar(LibName));

  try
    @Func := GetProcAddress(H, Pchar('_card_authorize9'));

    Result    := Func(Pchar(''), @FAuthAnswer9);
    FCheque   := PAnsiChar(FAuthAnswer9.AuthAnswer.Check);
    FRCode    := AnsiString(FAuthAnswer9.AuthAnswer.Rcode);
    FMessage  := AnsiString(FAuthAnswer9.AuthAnswer.AMessage);
    FAuthCode := AnsiString(FAuthAnswer9.AuthCode);
  finally
    Func := nil;
    FreeLibrary(H);
  end;
end;

function TPinPad.CloseDay: integer;
var
  Func: TCloseDay;
  H: THandle;
begin
  FAuthAnswer.TType  := integer(sberCloseDay);
  FAuthAnswer.Amount := 0;
  FAuthAnswer.CType  := 0;
  FAuthAnswer.Check  := PAnsiChar('');

  H := LoadLibrary(Pchar(LibName));
  if H <= 0 then
    begin
      raise Exception.create(Format('Не могу загрузить %s', [LibName]));
      Exit;
    end;

  @Func := GetProcAddress(H, Pchar('_close_day'));

  if not assigned(Func) then
    raise Exception.create('Could not find _close_day function');

  try
    Result   := Func(@FAuthAnswer);
    FCheque  := PAnsiChar(FAuthAnswer.Check);
    FMessage := AnsiString(FAuthAnswer.AMessage);
    FRCode   := AnsiString(FAuthAnswer.Rcode);
  except
    on E: Exception do
      raise Exception.create(E.Message);
  end;

  FreeLibrary(H);
end;

function TPinPad.CommitTrx: integer;
var
  H: THandle;
  Func: TCommitTrx;
begin
  H := LoadLibrary(Pchar(LibName));
  if H <= 0 then
    begin
      raise Exception.create(Format('Не могу загрузить %s', [LibName]));
      Exit;
    end;

  try
    @Func := GetProcAddress(H, Pchar('_CommitTrx'));
    try
      Result := Func(FAuthAnswer.Amount, PAnsiString(AnsiString(FAuthCode)));
    except
      on E: Exception do;
    end;

  finally
    FreeLibrary(H);
  end;

end;

constructor TPinPad.create;
begin
  inherited create;
  FAuthAnswer.Amount := 0;
  FAuthAnswer.TType  := 0;
end;

destructor TPinPad.destroy;
begin
  inherited destroy;
end;

function TPinPad.ReadTrack2: string;
var
  H: THandle;
  Func: TReadTrack2;
  Res: Pchar;
begin
  GetMem(Res, 255);

  H := LoadLibrary(Pchar(LibName));

  if H <= 0 then
    begin
      raise Exception.create(Format('Не могу загрузить %s', [LibName]));
      Exit;
    end;

  try
    @Func := GetProcAddress(H, Pchar('_ReadTrack2'));
    try
      Func(Res);
      Result := PAnsiChar(Res);
    except
      on E: Exception do;
    end;

  finally
    FreeMem(Res, sizeof(Res^));
    FreeLibrary(H);
  end;

end;

function TPinPad.RollBackTrx: integer;
var
  H: THandle;
  Func: TRollBackTrx;
begin
  H := LoadLibrary(Pchar(LibName));

  if H <= 0 then
    begin
      raise Exception.create(Format('Не могу загрузить %s', [LibName]));
      Exit;
    end;

  try
    @Func := GetProcAddress(H, Pchar('_RollbackTrx'));
    try
      Result := Func(FAuthAnswer.Amount, PAnsiString(AnsiString(FAuthCode)));
    except
      on E: Exception do;
    end;

  finally
    FreeLibrary(H);
  end;

end;

function TPinPad.SuspendTrx: integer;
var
  H: THandle;
  Func: TSuspendTrx;
begin
  H := LoadLibrary(Pchar(LibName));
  if H <= 0 then
    begin
      raise Exception.create(Format('Не могу загрузить %s', [LibName]));
      Exit;
    end;

  try
    @Func := GetProcAddress(H, Pchar('_SuspendTrx'));
    try
      Result := Func(FAuthAnswer.Amount, PAnsiString(AnsiString(FAuthCode)));
    except
      on E: Exception do;
    end;

  finally
    FreeLibrary(H);
  end;

end;

function TPinPad.TestPinPad: boolean;
var
  H: THandle;
  Func: TTestPinPad;
begin
  Result := false;

  try
    H := LoadLibrary(Pchar(LibName));
    if H <= 0 then
      begin
        raise Exception.create(Format('Не могу загрузить %s', [LibName]));
        Exit;
      end;

    @Func := GetProcAddress(H, Pchar('_TestPinpad'));
    try
      Result := Func = 0;
    except
      on E: Exception do;
    end;

  finally
    Func := nil;
    FreeLibrary(H);
  end;
end;

end.
