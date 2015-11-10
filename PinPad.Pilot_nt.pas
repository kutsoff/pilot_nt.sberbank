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

// Свернуть все регионы
// Shift + Ctrl + K + R

unit PinPad.Pilot_nt;

interface

uses Classes, Windows, SysUtils, Generics.Collections;

const
  LibName: string = '.\pinpad\pilot_nt.dll';

{$REGION 'Константы'}
  // Типы операций
  OP_PURCHASE = 1; // Оплата покупки
  OP_RETURN = 3; // Возврат либо отмена покупки
  OP_FUNDS = 6; // Безнал.перевод

  OP_CLOSEDAY = 7; // Закрытие дня (Сверка итогов)
  OP_SHIFT = 9; // Контрольная лента (НЕ ПРОВЕРЕНО)

  OP_PREAUTH = 51; // Предавторизация
  OP_COMPLETION = 52; // Завершение расчета
  OP_CASHIN = 53; // Взнос наличных
  OP_CASHIN_COMP = 54; // Подтверждение взноса

  // Типы карт
  CT_USER = 0; // Выбор из меню

  CT_VISA = 1; // Visa
  CT_EUROCARD = 2; // Eurocard/Mastercard
  CT_CIRRUS = 3; // Cirrus/Maestro
  CT_AMEX = 4; // Amex
  CT_DINERS = 5; // DinersCLub
  CT_ELECTRON = 6; // VisaElectron
  CT_PRO100 = 7; // PRO100
  CT_CASHIER = 8; // Cashier card
  CT_SBERCARD = 9; // Sbercard

  MAX_ENCR_DATA = 32;
{$ENDREGION}

type

{$REGION 'Документация и обертка над dll'}
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

  // Расширенная структура
  PAuthAnswer2 = ^TAuthAnswer2;

  TAuthAnswer2 = packed record
    AuthAnswer: TAuthAnswer;
    AuthCode: array [0 .. 6] of AnsiChar;
  end;

  // Еще одна расширенная структура
  PAuthAnswer3 = ^TAuthAnswer3;

  TAuthAnswer3 = packed record
    AuthAnswer: TAuthAnswer;
    AuthCode: array [0 .. 6] of AnsiChar;
    CardID: array [0 .. 24] of AnsiChar;
  end;

  // Еще более расширенная структура
  PAuthAnswer4 = ^TAuthAnswer4;

  TAuthAnswer4 = packed record
    AuthAnswer: TAuthAnswer;
    AuthCode: array [0 .. 6] of AnsiChar; // выход: код авторизации
    CardID: array [0 .. 24] of AnsiChar; // выход: идентификатор карты
    ErrorCode: integer; // выход: код ошибки
    TransDate: array [0 .. 19] of AnsiChar; // выход: дата и время операции
    TransNumber: integer; // выход: номер операции
  end;

  // Еще более расширенная структура
  PAuthAnswer5 = ^TAuthAnswer5;

  TAuthAnswer5 = packed record
    AuthAnswer: TAuthAnswer;
    RRN: array [0 .. 12] of AnsiChar;
    AuthCode: array [0 .. 6] of AnsiChar;
  end;

  PAuthAnswer6 = ^TAuthAnswer6;

  TAuthAnswer6 = packed record
    AuthAnswer: TAuthAnswer;
    AuthCode: array [0 .. 6] of AnsiChar; // added after communication with HRS
    CardID: array [0 .. 24] of AnsiChar; // выход: идентификатор карты
    ErrorCode: integer;
    TransDate: array [0 .. 19] of AnsiChar; // выход: дата и время операции
    TransNumber: integer; // выход: номер операции
    RRN: Array [0 .. 12] of AnsiChar;
    // вход/выход: ссылочный номер предавторизации
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

  PAuthAnswer8 = ^TAuthAnswer8;

  TAuthAnswer8 = packed record
    AuthAnswer: TAuthAnswer;
    // вход/выход: основные параметры операции (см.выше)
    AuthCode: array [0 .. 6] of AnsiChar; // Код авторизации
    // OUT При успешной авторизации (по международной карте) содержит код авторизации. При операции по карте Сберкарт поле будет заполнено символами ‘*’.
    CardID: array [0 .. 24] of AnsiChar; // номер карты
    // OUT При успешной авторизации (по международной карте) содержит номер карты. Для международных карт все символы, кроме первых 6 и последних 4, будут заменены символами ‘*’.
    ErrorCode: integer;
    TransDate: array [0 .. 19] of AnsiChar; // выход: дата и время операции
    TransNumber: integer; // выход: номер операции
    RRN: Array [0 .. 12] of AnsiChar;
    EncryptedData: array [0 .. MAX_ENCR_DATA * 2] of AnsiChar;
    // вход/выход: шифрованый номер карты и срок действия
  end;

  // Ответ предавторизации
  PPreauthRec = ^TPreauthRec;

  TPreauthRec = packed record
    Amount: UINT; // вход: сумма предавторизации в копейках
    RRN: array [0 .. 12] of AnsiChar; // вход: ссылочный номер предавторизации
    Last4Digits: array [0 .. 4] of AnsiChar;
    // вход: последние 4 цифры номера карты
    ErrorCode: UINT; // выход: код завершения: 0 - успешно.
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

  PAuthAnswer10 = ^TAuthAnswer10;

  TAuthAnswer10 = packed record
    AuthAnswer: TAuthAnswer;
    AuthCode: array [0 .. 6] of AnsiChar; // Код авторизации
    CardID: array [0 .. 24] of AnsiChar; // номер карты
    ErrorCode: integer;
    TransDate: array [0 .. 19] of AnsiChar; // выход: дата и время операции
    TransNumber: integer; // выход: номер операции
    SberOwnCard: integer;
    Hash: array [0 .. 40] of AnsiChar;
    // выход: хеш от номера карты, в формате ASCII с нулевым байтом в конце
  end;

  PAuthAnswer11 = ^TAuthAnswer11;

  TAuthAnswer11 = packed record
    AuthAnswer: TAuthAnswer;
    AuthCode: array [0 .. 6] of AnsiChar; // Код авторизации
    CardID: array [0 .. 24] of AnsiChar; // номер карты
    ErrorCode: integer;
    TransDate: array [0 .. 19] of AnsiChar; // выход: дата и время операции
    TransNumber: integer; // выход: номер операции
    SberOwnCard: integer;
    Hash: array [0 .. 40] of AnsiChar;
    // выход: хеш от номера карты, в формате ASCII с нулевым байтом в конце
    Track3: array [0 .. 107] of AnsiChar; // выход: третья дорожка карты
  end;

  // Получение текущего отчета. При значении поля TType = 0 формируется
  // краткий отчет, иначе - полный
  // __declspec(dllexport) int get_statistics(struct auth_answer *auth_answer);
  TGetStatistics = function(auth_ans: PAuthAnswer): integer; cdecl;

  TCardAuthorize = function(track2: Pchar; auth_ans: PAuthAnswer)
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
  TCardAuthorize7 = function(track2: Pchar; auth_ans: PAuthAnswer7)
    : integer; cdecl;

  // Выполнение операций по картам с возвратом дополнительных данных.
  // track2 - данные дорожки карты с магнитной полосой. Если NULL, то
  // будет предложено считать карту
  //
  // auth_answer2...auth_answer7 - см. описание полей структуры
  // __declspec(dllexport) int  card_authorize8(char *track2, struct auth_answer8 *auth_answer);

  TCardAuthorize2 = function(track2: Pchar; auth_ans: PAuthAnswer2)
    : integer; cdecl;

  TCardAuthorize3 = function(track2: Pchar; auth_ans: PAuthAnswer3)
    : integer; cdecl;

  TCardAuthorize4 = function(track2: Pchar; auth_ans: PAuthAnswer4)
    : integer; cdecl;

  TCardAuthorize5 = function(track2: Pchar; auth_ans: PAuthAnswer5)
    : integer; cdecl;

  TCardAuthorize6 = function(track2: Pchar; auth_ans: PAuthAnswer6)
    : integer; cdecl;

  TCardAuthorize8 = function(track2: Pchar; auth_ans: PAuthAnswer8)
    : integer; cdecl;

  TCardAuthorize9 = function(track2: Pchar; auth_ans: PAuthAnswer9)
    : integer; cdecl;

  TCardAuthorize10 = function(track2: Pchar; auth_ans: PAuthAnswer10)
    : integer; cdecl;

  TCardAuthorize11 = function(track2: Pchar; auth_ans: PAuthAnswer11)
    : integer; cdecl;

  //
  // __declspec(dllexport) int card_complete_multi_auth8(char* track2,
  // struct auth_answer8* auth_ans,
  // struct preauth_rec*  pPreAuthList,
  // int NumAuths);
  TCardCompleteMultiAuth8 = function(track2: Pchar; auth_ans: PAuthAnswer8;
    pPreauthList: PPreauthRec; NumAuths: integer): integer; cdecl;

  // Деинициализация
  TDone = procedure(); cdecl;

  // Получение номера версии
  TGetVer = function(): UINT; cdecl;

  // Получить номер терминала
  TGetTerminalID = function(pTerminalID: Pchar): integer; cdecl;

  // Чтение карты (возвращаются 4 последние цифры и хеш от номера карты)
  TReadCard = function(Last4Digits: Pchar; Hash: Pchar): integer; cdecl;
  TReadCardSB = function(Last4Digits: Pchar; Hash: Pchar): integer; cdecl;

  {
    Функция проверяет наличие пинпада. При успешном выполнении возвращает 0 (пинпад подключен),
    при неудачном – код ошибки (пинпад не подключен или неисправен).
  }
  TTestPinPad = function(): integer; cdecl;

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
  TCloseDay = function(auth_ans: PAuthAnswer): integer; cdecl;

  {
    Чтение карты (возвращется полный номер и срок действия карты в формате YYMM)

    Номер может иметь длину от 13 до 19 цифр.
    Чтобы потом использовать эти данные для авторизации, их нужно будет
    сформатировать так:

    format('Track2 %s=%s', [CardNo, ValidThru])
  }
  TReadCardFull = function(CardNo: PAnsiString; ValidThru: PAnsiString)
    : integer;

  {
    //  Данные второй дорожки могут иметь длину до 40 символов.
    //  Вторая дорожка имеет формат:
    //
    //    nnnn...nn=yymmddd...d
    //
    //  где     '=' - символ-разделитель
    //      nnn...n - номер карты
    //      yymm    - срок действия карты (ГГММ)
    //      ddd...d - служебные данные карты

    Track2 - Буфер, куда функция записывает прочитанную 2-ю дорожку.
  }
  TReadTrack2 = function(track2: Pchar): integer; cdecl;

  // Чтение карты асинхронное
  //
  TEnableReader = function(hDestWindow: HWND; msg: UINT): integer; cdecl;
  TDisableReader = function(): integer; cdecl;

  // SuspendTrx
  {
    Функция переводит последнюю успешную транзакцию в «подвешенное» состояние. Если транзакция находится в этом состоянии, то при следующем сеансе связи с банком она будет отменена.
    Входные параметры:
    dwAmount - Сумма операции (в копейках).
    pAuthCode - Код авторизации.
    Функция сверяет переданные извне параметры (сумму и код авторизации) со значениями в последней успешной операции, которая была проведена через библиотеку. Если хотя бы один параметр не совпадает, функция возвращает код ошибки 4140 и не выполняет никаких действий.
  }
  TSuspendTrx = function(dwAmount: DWORD; pAuthCode: PAnsiString)
    : integer; cdecl;

  // CommitTrx
  {
    Функция возвращает последнюю успешную транзакцию в «нормальное» состояние. После этого транзакция будет включена в отчет и спроцессирована как успешная. Перевести ее снова в «подвешенное» состояние будет уже нельзя.
    Входные параметры:
    dwAmount - Сумма операции (в копейках).
    pAuthCode - Код авторизации.
    Функция сверяет переданные извне параметры (сумму и код авторизации) со значениями в последней успешной операции, которая была проведена через библиотеку. Если хотя бы один параметр не совпадает, функция возвращает код ошибки 4140 и не выполняет никаких действий.
  }
  TCommitTrx = function(dwAmount: DWORD; pAuthCode: PAnsiString)
    : integer; cdecl;

  // RollBackTrx
  {
    Функция вызывает немедленную отмену последней успешной операции (возможно, ранее переведенную в «подвешенное» состояние, хотя это и не обязательно). Если транзакция уже была возвращена в «нормальное» состояние функцией CommitTrx(), то функция RollbackTrx() завершится с кодом ошибки 4141, не выполняя никаких действий.

    Входные параметры:
    dwAmount - Сумма операции (в копейках).
    pAuthCode - Код авторизации.
    Функция сверяет переданные извне параметры (сумму и код авторизации) со значениями в последней успешной операции, которая была проведена через библиотеку. Если хотя бы один параметр не совпадает, функция возвращает код ошибки 4140 и не выполняет никаких действий.
  }
  TRollBackTrx = function(dwAmount: DWORD; pAuthCode: PAnsiString)
    : integer; cdecl;

  // Войти в техническое меню.
  // При выходе поле Check может содержать образ документа для печати.
  //
  TServiceMenu = function(AuthAnswer: PAuthAnswer): integer; cdecl;

  // Установить хендлы для вывода на экран
  //
  TSetGUIHandles = function(hText: HWND; hEdit: HWND): integer; cdecl;

  TReadCardTrack3 = function(Last4Digits: Pchar; Hash: Pchar; pTrack3: Pchar)
    : integer; cdecl;

  TAbortTransaction = function(): integer; cdecl;

{$ENDREGION}

type
  TPinpadException = class(Exception);

  TPinPad = class(TObject)
  strict private
    FTerminalID: string; // номер терминала
    FGUITextHandle: HWND; // Хендлы для GUI
    FGUIEditHandle: HWND; //
    FAuthAnswer: TAuthAnswer;
    FAuthAnswer2: TAuthAnswer2;
    FAuthAnswer3: TAuthAnswer3;
    FAuthAnswer4: TAuthAnswer4;
    FAuthAnswer5: TAuthAnswer5;
    FAuthAnswer6: TAuthAnswer6;
    FAuthAnswer7: TAuthAnswer7;
    FAuthAnswer8: TAuthAnswer8;
    FAuthAnswer9: TAuthAnswer9;
    FAuthAnswer10: TAuthAnswer10;
    FAuthAnswer11: TAuthAnswer11;

    FCheque: String;
    FAuthCode: String;
    FCardID: String;
    FRRN: String;

    FLastError: integer;
    FLastErrorMessage: string;
  protected
    // Получить ID терминала
    function GetTerminalID: string;

    function SetGUIHandles(ATextHandle: HWND; AEditHandle: HWND): integer;

    // Сбросить все буферы
    procedure ClearBuffers;
    function GetLastErrorMessage: string;
  public
    // Если создаем с хендлами, то отображаем все в них, иначе будет нативный интерфейс сбера
    function Initialize(ATextHandle: HWND; AEditHandle: HWND): boolean;
    // Деинициализация (вызов _Done из библиотеки)
    procedure Done;

    destructor Destroy; reintroduce; override;

    // Получить текст ошибки по коду
    function GetMessageText(ErrorCode: integer): String;

    // Проверяем готовность пинпада
    function TestPinpad: boolean;

    // Авторизация, оплата, возврат
    function CardAuth(Summ: Double; Operation: integer): integer;
    function CardAuth2(Summ: Double; Operation: integer): integer;
    function CardAuth3(Summ: Double; Operation: integer): integer;
    function CardAuth4(Summ: Double; Operation: integer): integer;
    function CardAuth5(Summ: Double; Operation: integer): integer;
    function CardAuth6(Summ: Double; Operation: integer): integer;
    function CardAuth7(Summ: Double; Operation: integer): integer;
    function CardAuth8(Summ: Double; Operation: integer): integer;
    function CardAuth9(Summ: Double; Operation: integer): integer;
    function CardAuth10(Summ: Double; Operation: integer): integer;
    function CardAuth11(Summ: Double; Operation: integer): integer;

    function ReadTrack2: string;
    function ReadTrack3: string;

    function SuspendTrx: integer;
    function CommitTrx: integer;
    function RollBackTrx: integer;

    function TryReturn(Amount: Double): boolean;
    function TryPurchase(Amount: Double): boolean;

    // Немедленная отмена транзакции и незавершенных транзакций
    function AbortTransaction: integer;
    // Контрольная лента
    function SberShift(IsDetailed: boolean = False): integer;
    // Сверка итогов
    function CloseDay: integer;
    // Сервисное меню
    function ServiceMenu: integer;
  published
    property TerminalID: string read GetTerminalID;
    property AuthAnswer: TAuthAnswer read FAuthAnswer;
    property AuthAnswer2: TAuthAnswer2 read FAuthAnswer2;
    property AuthAnswer3: TAuthAnswer3 read FAuthAnswer3;
    property AuthAnswer4: TAuthAnswer4 read FAuthAnswer4;
    property AuthAnswer5: TAuthAnswer5 read FAuthAnswer5;
    property AuthAnswer6: TAuthAnswer6 read FAuthAnswer6;
    property AuthAnswer7: TAuthAnswer7 read FAuthAnswer7;
    property AuthAnswer8: TAuthAnswer8 read FAuthAnswer8;
    property AuthAnswer9: TAuthAnswer9 read FAuthAnswer9;
    property AuthAnswer10: TAuthAnswer10 read FAuthAnswer10;
    property AuthAnswer11: TAuthAnswer11 read FAuthAnswer11;

    property Cheque: string read FCheque;
    property CardID: string read FCardID;
    property AuthCode: string read FAuthCode;
    property RRN: string read FRRN;

    property LastError: integer read FLastError;
    property LastErrorMessage: string read GetLastErrorMessage;
  end;

implementation

{ TPinPad }

function TPinPad.AbortTransaction: integer;
var
  H: THandle;
  Func: TAbortTransaction;
begin

  H := LoadLibrary(Pchar(LibName));

  if H <= 0 then
  begin
    raise TPinpadException.Create(Format('Не могу загрузить %s', [LibName]));
    Exit;
  end;

  try
    @Func := GetProcAddress(H, Pchar('_AbortTransaction'));

    if not Assigned(Func) then
      raise TPinpadException.Create
        ('Функция _AbortTransaction не найдена в pilot_nt.dll');

    try
      Result := Func;
      FLastError := Result;
    except
      on E: Exception do
        RaiseLastOSError;
    end;

  finally
    Func := nil;
    FreeLibrary(H);
  end;
end;

function TPinPad.CardAuth(Summ: Double; Operation: integer): integer;
var
  H: THandle;
  Func: TCardAuthorize;
  Sum: UINT;
begin
  ClearBuffers;

  Sum := Round(Summ * 100);
  FAuthAnswer.Amount := Sum;
  FAuthAnswer.TType := Operation;
  FAuthAnswer.CType := 0;

  H := LoadLibrary(Pchar(LibName));

  try
    @Func := GetProcAddress(H, Pchar('_card_authorize'));

    if not Assigned(Func) then
      raise TPinpadException.Create
        ('Функция _card_authorize не найдена в pilot_nt.dll');

    try

      Result := Func(nil, @FAuthAnswer);
      FLastError := Result;

      FCheque := PAnsiChar(FAuthAnswer.Check);

      FLastErrorMessage := AnsiString(FAuthAnswer.AMessage);
    except
      on E: Exception do
        RaiseLastOSError;
    end;
  finally
    Func := nil;
    FreeLibrary(H);
  end;
end;

function TPinPad.CardAuth10(Summ: Double; Operation: integer): integer;
var
  H: THandle;
  Func: TCardAuthorize10;
  Sum: UINT;
begin
  ClearBuffers;

  Sum := Round(Summ * 100);
  FAuthAnswer.Amount := Sum;
  FAuthAnswer.TType := Operation;
  FAuthAnswer.CType := 0;

  FAuthAnswer10.AuthAnswer := FAuthAnswer;

  H := LoadLibrary(Pchar(LibName));

  try
    @Func := GetProcAddress(H, Pchar('_card_authorize10'));

    if not Assigned(Func) then
      raise TPinpadException.Create
        ('Функция _card_authorize10 не найдена в pilot_nt.dll');

    try
      Result := Func(nil, @FAuthAnswer10);
      FLastError := Result;

      FAuthAnswer := FAuthAnswer10.AuthAnswer;
      FCheque := PAnsiChar(FAuthAnswer.Check);
      FAuthCode := AnsiString(FAuthAnswer10.AuthCode);
      FCardID := AnsiString(FAuthAnswer10.CardID);
      FLastErrorMessage := AnsiString(FAuthAnswer.AMessage);

    except
      on E: Exception do
        RaiseLastOSError;
    end;
  finally
    Func := nil;
    FreeLibrary(H);
  end;
end;

function TPinPad.CardAuth11(Summ: Double; Operation: integer): integer;
var
  H: THandle;
  Func: TCardAuthorize11;
  Sum: UINT;
begin
  ClearBuffers;

  Sum := Round(Summ * 100);
  FAuthAnswer.Amount := Sum;
  FAuthAnswer.TType := Operation;
  FAuthAnswer.CType := 0;

  FAuthAnswer11.AuthAnswer := FAuthAnswer;

  H := LoadLibrary(Pchar(LibName));

  try
    @Func := GetProcAddress(H, Pchar('_card_authorize11'));

    if not Assigned(Func) then
      raise TPinpadException.Create
        ('Функция _card_authorize11 не найдена в pilot_nt.dll');

    try
      Result := Func(nil, @FAuthAnswer11);
      FLastError := Result;

      FAuthAnswer := FAuthAnswer11.AuthAnswer;
      FCheque := PAnsiChar(FAuthAnswer.Check);
      FAuthCode := AnsiString(FAuthAnswer11.AuthCode);
      FCardID := AnsiString(FAuthAnswer11.CardID);
      FLastErrorMessage := AnsiString(FAuthAnswer.AMessage);
    except
      on E: Exception do
        RaiseLastOSError;
    end;
  finally
    Func := nil;
    FreeLibrary(H);
  end;
end;

function TPinPad.CardAuth2(Summ: Double; Operation: integer): integer;
var
  H: THandle;
  Func: TCardAuthorize2;
  Sum: UINT;
begin
  ClearBuffers;

  Sum := Round(Summ * 100);
  FAuthAnswer.Amount := Sum;
  FAuthAnswer.TType := Operation;
  FAuthAnswer.CType := 0;

  FAuthAnswer2.AuthAnswer := FAuthAnswer;

  H := LoadLibrary(Pchar(LibName));

  try
    @Func := GetProcAddress(H, Pchar('_card_authorize2'));

    if not Assigned(Func) then
      raise TPinpadException.Create
        ('Функция _card_authorize2 не найдена в pilot_nt.dll');

    try
      Result := Func(nil, @FAuthAnswer2);
      FLastError := Result;

      FAuthAnswer := FAuthAnswer2.AuthAnswer;
      FCheque := PAnsiChar(FAuthAnswer.Check);
      FAuthCode := AnsiString(FAuthAnswer2.AuthCode);
      FLastErrorMessage := AnsiString(FAuthAnswer.AMessage);

    except
      on E: Exception do
        RaiseLastOSError;
    end;
  finally
    Func := nil;
    FreeLibrary(H);
  end;
end;

function TPinPad.CardAuth3(Summ: Double; Operation: integer): integer;
var
  H: THandle;
  Func: TCardAuthorize3;
  Sum: UINT;
begin
  ClearBuffers;

  Sum := Round(Summ * 100);
  FAuthAnswer.Amount := Sum;
  FAuthAnswer.TType := Operation;
  FAuthAnswer.CType := 0;

  FAuthAnswer3.AuthAnswer := FAuthAnswer;

  H := LoadLibrary(Pchar(LibName));

  try
    @Func := GetProcAddress(H, Pchar('_card_authorize3'));

    if not Assigned(Func) then
      raise TPinpadException.Create
        ('Функция _card_authorize3 не найдена в pilot_nt.dll');

    try
      Result := Func(nil, @FAuthAnswer3);
      FLastError := Result;

      FAuthAnswer := FAuthAnswer3.AuthAnswer;
      FCheque := PAnsiChar(FAuthAnswer.Check);
      FAuthCode := AnsiString(FAuthAnswer3.AuthCode);
      FCardID := AnsiString(FAuthAnswer3.CardID);
      FLastErrorMessage := AnsiString(FAuthAnswer.AMessage);

    except
      on E: Exception do
        RaiseLastOSError;
    end;
  finally
    Func := nil;
    FreeLibrary(H);
  end;
end;

function TPinPad.CardAuth4(Summ: Double; Operation: integer): integer;
var
  H: THandle;
  Func: TCardAuthorize4;
  Sum: UINT;
begin
  ClearBuffers;

  Sum := Round(Summ * 100);
  FAuthAnswer.Amount := Sum;
  FAuthAnswer.TType := Operation;
  FAuthAnswer.CType := 0;

  FAuthAnswer7.AuthAnswer := FAuthAnswer;

  H := LoadLibrary(Pchar(LibName));

  try
    @Func := GetProcAddress(H, Pchar('_card_authorize4'));

    if not Assigned(Func) then
      raise TPinpadException.Create
        ('Функция _card_authorize4 не найдена в pilot_nt.dll');

    try
      Result := Func(nil, @FAuthAnswer4);
      FLastError := Result;

      FAuthAnswer := FAuthAnswer4.AuthAnswer;
      FCheque := PAnsiChar(FAuthAnswer.Check);
      FAuthCode := AnsiString(FAuthAnswer4.AuthCode);
      FCardID := AnsiString(FAuthAnswer4.CardID);
      FLastErrorMessage := AnsiString(FAuthAnswer.AMessage);

    except
      on E: Exception do
        RaiseLastOSError;
    end;
  finally
    Func := nil;
    FreeLibrary(H);
  end;
end;

function TPinPad.CardAuth5(Summ: Double; Operation: integer): integer;
var
  H: THandle;
  Func: TCardAuthorize5;
  Sum: UINT;
begin
  ClearBuffers;

  Sum := Round(Summ * 100);
  FAuthAnswer.Amount := Sum;
  FAuthAnswer.TType := Operation;
  FAuthAnswer.CType := 0;

  FAuthAnswer5.AuthAnswer := FAuthAnswer;

  H := LoadLibrary(Pchar(LibName));

  try
    @Func := GetProcAddress(H, Pchar('_card_authorize5'));

    if not Assigned(Func) then
      raise TPinpadException.Create
        ('Функция _card_authorize5 не найдена в pilot_nt.dll');

    try
      Result := Func(nil, @FAuthAnswer5);
      FLastError := Result;

      FAuthAnswer := FAuthAnswer5.AuthAnswer;
      FCheque := PAnsiChar(FAuthAnswer.Check);
      FAuthCode := AnsiString(FAuthAnswer5.AuthCode);
      FLastErrorMessage := AnsiString(FAuthAnswer.AMessage);

    except
      on E: Exception do
        RaiseLastOSError;
    end;
  finally
    Func := nil;
    FreeLibrary(H);
  end;
end;

function TPinPad.CardAuth6(Summ: Double; Operation: integer): integer;
var
  H: THandle;
  Func: TCardAuthorize6;
  Sum: UINT;
begin
  ClearBuffers;

  Sum := Round(Summ * 100);
  FAuthAnswer.Amount := Sum;
  FAuthAnswer.TType := Operation;
  FAuthAnswer.CType := 0;

  FAuthAnswer6.AuthAnswer := FAuthAnswer;

  H := LoadLibrary(Pchar(LibName));

  try
    @Func := GetProcAddress(H, Pchar('_card_authorize6'));

    if not Assigned(Func) then
      raise TPinpadException.Create
        ('Функция _card_authorize6 не найдена в pilot_nt.dll');

    try
      Result := Func(nil, @FAuthAnswer6);
      FLastError := Result;

      FAuthAnswer := FAuthAnswer6.AuthAnswer;
      FCheque := PAnsiChar(FAuthAnswer.Check);
      FAuthCode := AnsiString(FAuthAnswer6.AuthCode);
      FCardID := AnsiString(FAuthAnswer6.CardID);
      FLastErrorMessage := AnsiString(FAuthAnswer.AMessage);

    except
      on E: Exception do
        RaiseLastOSError;
    end;
  finally
    Func := nil;
    FreeLibrary(H);
  end;
end;

function TPinPad.CardAuth7(Summ: Double; Operation: integer): integer;
var
  H: THandle;
  Func: TCardAuthorize7;
  Sum: UINT;
begin
  ClearBuffers;

  Sum := Round(Summ * 100);
  FAuthAnswer.Amount := Sum;
  FAuthAnswer.TType := Operation;
  FAuthAnswer.CType := 0;

  FAuthAnswer7.AuthAnswer := FAuthAnswer;

  H := LoadLibrary(Pchar(LibName));

  try
    @Func := GetProcAddress(H, Pchar('_card_authorize7'));

    if not Assigned(Func) then
      raise TPinpadException.Create
        ('Функция _card_authorize7 не найдена в pilot_nt.dll');

    try
      Result := Func(nil, @FAuthAnswer7);
      FLastError := Result;

      FAuthAnswer := FAuthAnswer7.AuthAnswer;
      FCheque := PAnsiChar(FAuthAnswer.Check);
      FAuthCode := AnsiString(FAuthAnswer7.AuthCode);
      FCardID := AnsiString(FAuthAnswer7.CardID);
      FLastErrorMessage := AnsiString(FAuthAnswer.AMessage);

    except
      on E: Exception do
        RaiseLastOSError;
    end;
  finally
    Func := nil;
    FreeLibrary(H);
  end;
end;

function TPinPad.CardAuth8(Summ: Double; Operation: integer): integer;
var
  H: THandle;
  Func: TCardAuthorize8;
  Sum: UINT;
begin
  ClearBuffers;

  Sum := Round(Summ * 100);
  FAuthAnswer.Amount := Sum;
  FAuthAnswer.TType := Operation;
  FAuthAnswer.CType := 0;

  FAuthAnswer8.AuthAnswer := FAuthAnswer;

  H := LoadLibrary(Pchar(LibName));

  try
    @Func := GetProcAddress(H, Pchar('_card_authorize8'));

    if not Assigned(Func) then
      raise TPinpadException.Create
        ('Функция _card_authorize8 не найдена в pilot_nt.dll');

    try
      Result := Func(nil, @FAuthAnswer8);
      FLastError := Result;

      FAuthAnswer := FAuthAnswer8.AuthAnswer;
      FCheque := PAnsiChar(FAuthAnswer.Check);
      FAuthCode := AnsiString(FAuthAnswer8.AuthCode);
      FCardID := AnsiString(FAuthAnswer8.CardID);
      FLastErrorMessage := AnsiString(FAuthAnswer.AMessage);

    except
      on E: Exception do
        RaiseLastOSError;
    end;
  finally
    Func := nil;
    FreeLibrary(H);
  end;
end;

function TPinPad.CardAuth9(Summ: Double; Operation: integer): integer;
var
  H: THandle;
  Func: TCardAuthorize9;
  Sum: UINT;
begin
  ClearBuffers;

  Sum := Round(Summ * 100);
  FAuthAnswer.Amount := Sum;
  FAuthAnswer.TType := Operation;
  FAuthAnswer.CType := 0;

  FAuthAnswer9.AuthAnswer := FAuthAnswer;

  H := LoadLibrary(Pchar(LibName));

  try
    @Func := GetProcAddress(H, Pchar('_card_authorize9'));

    if not Assigned(Func) then
      raise TPinpadException.Create
        ('Функция _card_authorize9 не найдена в pilot_nt.dll');

    try
      Result := Func(nil, @FAuthAnswer9);
      FLastError := Result;

      FAuthAnswer := FAuthAnswer9.AuthAnswer;
      FCheque := PAnsiChar(FAuthAnswer.Check);
      FAuthCode := AnsiString(FAuthAnswer9.AuthCode);
      FCardID := AnsiString(FAuthAnswer9.CardID);
      FLastErrorMessage := AnsiString(FAuthAnswer.AMessage);
    except
      on E: Exception do
        RaiseLastOSError;
    end;
  finally
    Func := nil;
    FreeLibrary(H);
  end;
end;

procedure TPinPad.ClearBuffers;
begin
  ZeroMemory(@FAuthAnswer, SizeOf(FAuthAnswer));
  ZeroMemory(@FAuthAnswer2, SizeOf(FAuthAnswer2));
  ZeroMemory(@FAuthAnswer3, SizeOf(FAuthAnswer3));
  ZeroMemory(@FAuthAnswer4, SizeOf(FAuthAnswer4));
  ZeroMemory(@FAuthAnswer5, SizeOf(FAuthAnswer5));
  ZeroMemory(@FAuthAnswer6, SizeOf(FAuthAnswer6));
  ZeroMemory(@FAuthAnswer7, SizeOf(FAuthAnswer7));
  ZeroMemory(@FAuthAnswer8, SizeOf(FAuthAnswer8));
  ZeroMemory(@FAuthAnswer9, SizeOf(FAuthAnswer9));
  ZeroMemory(@FAuthAnswer10, SizeOf(FAuthAnswer10));
  ZeroMemory(@FAuthAnswer11, SizeOf(FAuthAnswer11));

  FLastError := 0;
  FLastErrorMessage := '';
  FAuthCode := '';
  FRRN := '';
  FCardID := '';
  FCheque := '';
end;

function TPinPad.CloseDay: integer;
var
  Func: TCloseDay;
  H: THandle;
begin
  ClearBuffers;

  FAuthAnswer.TType := OP_CLOSEDAY;
  FAuthAnswer.Amount := 0;
  FAuthAnswer.CType := 0;
  FAuthAnswer.Check := PAnsiChar('');

  H := LoadLibrary(Pchar(LibName));
  if H <= 0 then
  begin
    raise TPinpadException.Create(Format('Не могу загрузить %s', [LibName]));
    Exit;
  end;

  try

    @Func := GetProcAddress(H, Pchar('_close_day'));

    if not Assigned(Func) then
      raise TPinpadException.Create
        ('Функция _close_day не найдена в pilot_nt.dll');

    try
      Result := Func(@FAuthAnswer);
      FLastError := Result;
      FLastErrorMessage := PAnsiChar(@AuthAnswer.AMessage);
      FCheque := PAnsiChar(AuthAnswer.Check);
    except
      on E: Exception do
        raise TPinpadException.Create(E.message);
    end;

  finally
    Func := nil;
    FreeLibrary(H);
  end;
end;

function TPinPad.CommitTrx: integer;
var
  H: THandle;
  Func: TCommitTrx;
begin
  H := LoadLibrary(Pchar(LibName));
  if H <= 0 then
  begin
    raise TPinpadException.Create(Format('Не могу загрузить %s', [LibName]));
    Exit;
  end;

  try
    @Func := GetProcAddress(H, Pchar('_CommitTrx'));

    if not Assigned(Func) then
      raise TPinpadException.Create
        ('Функция _CommitTrx не найдена в pilot_nt.dll');

    try
      Result := Func(FAuthAnswer.Amount, PAnsiString(AnsiString(FAuthCode)));
      FLastError := Result;
      FLastErrorMessage := GetMessageText(Result);
    except
      on E: Exception do
        RaiseLastOSError;
    end;

  finally
    Func := nil;
    FreeLibrary(H);
  end;
end;

{ DONE: Деструктор }
destructor TPinPad.Destroy;
begin
  ClearBuffers;
  Done;
  inherited Destroy;
end;

procedure TPinPad.Done;
var
  H: THandle;
  Func: TDone;
begin

  H := LoadLibrary(Pchar(LibName));

  if H <= 0 then
  begin
    raise TPinpadException.Create(Format('Не могу загрузить %s', [LibName]));
    Exit;
  end;

  try
    @Func := GetProcAddress(H, Pchar('_Done'));
    Func;
  finally
    Func := nil;
    FreeLibrary(H);
  end;
end;

{$REGION 'GetErrorMessage'}

function TPinPad.GetMessageText(ErrorCode: integer): String;
begin
  case ErrorCode of
    12:
      Result := 'Ошибка возникает обычно в ДОС-версиях. Возможных причин две: 1. В настройках указан неверный тип пинпада.'
        + ' Должно быть РС-2, а указано РС-3. 2. Если ошибка возникает неустойчиво, то скорее всего виноват СОМ-порт. Он или нестандартный, или неисправный. Попробовать перенести пинпад на другой порт, а лучше – на USB.';
    99:
      Result := 'Нарушился контакт с пинпадом, либо невозможно открыть указанный СОМ-порт (он или отсутствует в системе, или захвачен другой программой).';
    361, 362, 363, 364:
      Result := 'Нарушился контакт с чипом карты. Чип не читается. Попробовать вставить другую карту. Если ошибка возникает на всех картах – неисправен чиповый ридер пинпада.';
    403:
      Result := 'Клиент ошибся при вводе ПИНа (СБЕРКАРТ)';
    405:
      Result := 'ПИН клиента заблокирован (СБЕРКАРТ)';
    444, 507:
      Result := 'Истек срок действия карты (СБЕРКАРТ)';
    518:
      Result := 'На терминале установлена неверная дата';
    521:
      Result := 'На карте недостаточно средств (СБЕРКАРТ)';
    572:
      Result := 'Истек срок действия карты (СБЕРКАРТ)';
    574, 579:
      Result := 'Карта заблокирована (СБЕРКАРТ)';
    584, 585:
      Result := 'Истек период обслуживания карты (СБЕРКАРТ)';
    705, 706, 707:
      Result := 'Карта заблокирована (СБЕРКАРТ)';
    708, 709:
      Result := 'ПИН клиента заблокирован (СБЕРКАРТ)';
    2000:
      Result := 'Операция прервана нажатием клавиши ОТМЕНА. Другая возможная причина – не проведена предварительная сверка итогов, и на терминале еще нет сеансовых ключей.';
    2002:
      Result := 'Клиент слишком долго вводит ПИН. Истек таймаут.';
    2004, 2005, 2006, 2007, 2405, 2406, 2407:
      Result := 'Карта заблокирована (СБЕРКАРТ)';
    3001:
      Result := 'Недостаточно средств для загрузки на карту (СБЕРКАРТ)';
    3002:
      Result := 'По карте клиента числится прерванная загрузка средств (СБЕРКАРТ)';
    3019, 3020, 3021:
      Result := 'На сервере проводятся регламентные работы (СБЕРКАРТ)';
    4100:
      Result := 'Нет связи с банком при удаленной загрузке. Возможно, на терминале неверно задан параметр «Код региона и участника для удаленной загрузки».';
    4101, 4102:
      Result := 'Карта терминала не проинкассирована';
    4103, 4104:
      Result := 'Ошибка обмена с чипом карты';
    4108:
      Result := 'Неправильно введен или прочитан номер карты (ошибка контрольного разряда)';
    4110, 4111, 4112:
      Result := 'Требуется проинкассировать карту терминала (СБЕРКАРТ)';
    4113, 4114:
      Result := 'Превышен лимит, допустимый без связи с банком (СБЕРКАРТ)';
    4115:
      Result := 'Ручной ввод для таких карт запрещен';
    4116:
      Result := 'Введены неверные 4 последних цифры номера карты';
    4117:
      Result := 'Клиент отказался от ввода ПИНа';
    4119:
      Result := 'Нет связи с банком. Другая возможная причина – неверный ключ KLK для пинпада Verifone pp1000se или встроенного пинпада Verifone.'
        + ' Если терминал Verifone работает по Ethernet, то иногда избавиться от ошибки можно, понизив скорость порта с 115200 до 57600 бод.';
    4120:
      Result := 'В пинпаде нет ключа KLK.';
    4121:
      Result := 'Ошибка файловой структуры терминала. Невозможно записать файл BTCH.D.';
    4122:
      Result := 'Ошибка смены ключей: либо на хосте нет нужного KLK, либо в настройках терминала указан неверный мерчант.';
    4123:
      Result := 'На терминале нет сеансовых ключей';
    4124:
      Result := 'На терминале нет мастер-ключей';
    4125:
      Result := 'На карте есть чип, а прочитана была магнитная полоса';
    4128:
      Result := 'Неверный МАС — код при сверке итогов. Вероятно, неверный ключ KLK.';
    4130:
      Result := 'Память терминала заполнена. Пора делать сверку итогов (лучше несколько раз подряд, чтобы почистить старые отчеты).';
    4131:
      Result := 'Установлен тип пинпада РС-2, но с момента последней прогрузки параметров пинпад был заменен (изменился его серийный номер). Необходимо повторно прогрузить TLV-файл или выполнить удаленную загрузку.';
    4132:
      Result := 'Операция отклонена картой. Возможно, карту вытащили из чипового ридера до завершения печати чека. Повторить операцию заново. Если ошибка возникает постоянно, возможно, карта неисправна.';
    4134:
      Result := 'Слишком долго не выполнялась сверка итогов на терминале (прошло более 5 дней с момента последней операции).';
    4135:
      Result := 'Нет SAM-карты для выбранного отдела (СБЕРКАРТ)';
    4136:
      Result := 'Требуется более свежая версия прошивки в пинпаде.';
    4137:
      Result := 'Ошибка при повторном вводе нового ПИНа.';
    4138:
      Result := 'Номер карты получателя не может совпадать с номером карты отправителя.';
    4139:
      Result := 'В настройках терминала нет ни одного варианта связи, пригодного для требуемой операции.';
    4140:
      Result := 'Неверно указаны сумма или код авторизации в команде SUSPEND из кассовой программы.';
    4141:
      Result := 'Невозможно выполнить команду SUSPEND: не найден файл SHCN.D.';
    4142:
      Result := 'Не удалось выполнить команду ROLLBACK из кассовой прграммы.';
    4143:
      Result := 'На терминале слишком старый стоп-лист.';
    4144, 4145, 4146, 4147:
      Result := 'Неверный формат стоп-листа на терминале (для торговли в самолете без авторизации).';
    4148:
      Result := 'Карта в стоп-листе.';
    4149:
      Result := 'На карте нет фамилии держателя.';
    4150:
      Result := 'Превышен лимит, допустимый без связи с банком (для торговли на борту самолета без авторизации).';
    4151:
      Result := 'Истек срок действия карты (для торговли на борту самолета без авторизации).';
    4152:
      Result := 'На карте нет списка транзакций (ПРО100).';
    4153:
      Result := 'Список транзакций на карте имеет неизвестный формат (ПРО100).';
    4154:
      Result := 'Невозможно распечатать список транзакций карты, потому что его можно считать только с чипа, а прочитана магнитная полоса (ПРО100).';
    4155:
      Result := 'Список транзакций пуст (ПРО100).';
    4160:
      Result := 'Неверный ответ от карты при считывании биометрических данных';
    4161:
      Result := 'На терминале нет файла с биометрическим сертификатом BSCP.CR';
    4162, 4163, 4164:
      Result := 'Ошибка расшифровки биометрического сертификата карты. Возможно, неверный файл BSCP.CR';
    4165, 4166, 4167:
      Result := 'Ошибка взаимной аутентификации биосканера и карты. Возможно, неверный файл BSCP.CR';
    4168, 4169:
      Result := 'Ошибка расшифровки шаблонов пальцев, считанных с карты.';
    4171:
      Result := 'В ответе хоста на запрос enrollment’a нет биометрической криптограммы.';
    4202:
      Result := 'Сбой при удаленной загрузке: неверное смещение в данных.';
    4203:
      Result := 'Не указанный или неверный код активации при удаленной загрузке.';
    4208:
      Result := 'Ошибка удаленной загрузки: на сервере не активирован какой-либо шаблон для данного терминала.';
    4209:
      Result := 'Ошибка удаленной загрузки: на сервере проблемы с доступом к БД.';
    4211:
      Result := 'На терминале нет EMV-ключа с номером 62 (он нужен для удаленной загрузки).';
    4300:
      Result := 'Недостаточно параметров при запуске модуля sb_pilot. В командной строке указаны не все требуемые параметры.';
    4301:
      Result := 'Кассовая программа передала в UPOS недопустимый тип операции';
    4302:
      Result := 'Кассовая программа передала в UPOS недопустимый тип карты';
    4303:
      Result := 'Тип карты, переданный из кассовой программы, не значится в настройках UPOS. Возможно, на диске кассы имеется несколько '
        + ' каталогов с библиотекой UPOS. Банковский инженер настраивал один экземпляр, а кассовая программа обращается к другому, где никаких настроек (а значит, и типов карт) нет.';
    4305:
      Result := 'Ошибка инициализации библиотеки sb_kernel.dll. Кассовая программа ожидает библиотеку с более свежей версией.';
    4306:
      Result := '"Библиотека sb_kernel.dll не была инициализирована. Эта ошибка может разово возникать после обновления библиотеки через удаленную загрузку. Нужно просто повторить операцию."';
    4308:
      Result := 'В старых версиях этим кодом обозначалась любая из проблем, которые сейчас обозначаются кодами 4331-4342';
    4309:
      Result := 'Печатать нечего. Эта ошибка возникает в интегрированных решениях, которые выполнены не вполне корректно:'
        + ' в случае любой ошибки (нет связи, ПИН неверен, неверный ключ KLK и т.д.) кассовая программа все равно запрашивает у библиотеки '
        + ' sb_kernel.dll образ чека для печати. Поскольку по умолчанию библиотека при отказах чек не формирует, то на запрос чека она возвращает кассовой программе'
        + ' код 4309 – печатать нечего, нет документа для печати. Исходный код ошибки (тот, который обозначает причину отказа) кассовая программа при этом забывает.';
    4310:
      Result := 'Кассовая программа передала в UPOS недопустимый трек2.';
    4313:
      Result := 'В кассовой программе значится один номер карты, а через UPOS считан другой.';
    4314:
      Result := 'Кассовая программа передала код операции «Оплата по международной карте», а вставлена была карта СБЕРКАРТ.';
    4332:
      Result := 'Сверка итогов не выполнена (причина неизвестна, но печатать в итоге нечего).';
    4333:
      Result := 'Распечатать контрольную ленту невозможно (причина неизвестна, но печатать в итоге нечего).';
    4334:
      Result := 'Карта не считана. Либо цикл ожидания карты прерван нажатием клавиши ESC, либо просто истек таймаут.';
    4335:
      Result := 'Сумма не введена при операции ввода слипа.';
    4336:
      Result := 'Из кассовой программы передан неверный код валюты.';
    4337:
      Result := 'Из кассовой программы передан неверный тип карты.';
    4338:
      Result := 'Вызвана операция по карте СБЕРКАРТ, но прочитать карту СБЕРКАРТ не удалось.';
    4339:
      Result := 'Вызвана недопустимая операция по карте СБЕРКАРТ.';
    4340:
      Result := 'Ошибка повторного считывания карты СБЕРКАРТ.';
    4341:
      Result := 'Вызвана операция по карте СБЕРКАРТ, но вставлена карта другого типа, либо не вставлена никакая.';
    4342:
      Result := 'Ошибка: невозможно запустить диалоговое окно UPOS (тред почему-то не создается).';
    4400 - 4499:
      Result := Format('От фронтальной системы получен код ответа %d.',
        [ErrorCode - 4400]);
    5002:
      Result := 'Карта криво выпущена и поэтому дает сбой на терминалах, поддерживающих режим Offline Enciphered PIN.';
    5026:
      Result := 'Ошибка проверки RSA-подписи. На терминале отсутствует (или некорректный) один из ключей из раздела «Ключи EMV».';
    5063:
      Result := 'На карте ПРО100 нет списка транзакций.';
    5100 - 5108:
      Result := 'Нарушены данные на чипе карты';
    5109:
      Result := 'Срок действия карты истек';
    5110:
      Result := 'Срок действия карты еще не начался';
    5111:
      Result := 'Для этой карты такая операция не разрешена';
    5116, 5120:
      Result := 'Клиент отказался от ввода ПИНа';
    5133:
      Result := 'Операция отклонена картой';
  end;
end;

function TPinPad.GetLastErrorMessage: string;
begin
  if FLastErrorMessage <> '' then
    Result := FLastErrorMessage
  else
    Result := GetMessageText(FLastError);
end;

{$ENDREGION}

function TPinPad.GetTerminalID: string;
var
  H: THandle;
  Func: TGetTerminalID;
  S: Pchar;
begin
  GetMem(S, 255);

  H := LoadLibrary(Pchar(LibName));

  if H <= 0 then
  begin
    raise TPinpadException.Create(Format('Не могу загрузить %s', [LibName]));
    Exit;
  end;

  try
    @Func := GetProcAddress(H, Pchar('_GetTerminalID'));

    if not Assigned(Func) then
      raise TPinpadException.Create
        ('Функция GetTerminalID не найдена в pilot_nt.dll');
    try
      FLastError := Func(S);
      FLastErrorMessage := GetMessageText(FLastError);

      if FLastError = 0 then
        Result := PAnsiChar(S)
      else
        Result := '';
    except
      on E: Exception do
        RaiseLastOSError;
    end;
  finally
    FreeMem(S, SizeOf(S^));
    Func := nil;
    FreeLibrary(H);
  end;
end;

function TPinPad.Initialize(ATextHandle, AEditHandle: HWND): boolean;
begin
  Result := False;
  try
    FGUITextHandle := ATextHandle;
    FGUIEditHandle := AEditHandle;
    FTerminalID := '';
    ClearBuffers;

    if TestPinpad then
      try
        FTerminalID := GetTerminalID; // Сразу получаем номер терминала

        if (FGUITextHandle <> 0) and (FGUIEditHandle <> 0) then
          FLastError := SetGUIHandles(ATextHandle, AEditHandle);
      except
        on E: Exception do; // Ничего не делаем
      end;

  finally
    Result := FLastError = 0;
  end;

end;

function TPinPad.TryPurchase(Amount: Double): boolean;
begin
  Result := (CardAuth7(Amount, OP_PURCHASE) = 0) and (SuspendTrx = 0);
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
    raise TPinpadException.Create(Format('Не могу загрузить %s', [LibName]));
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
    FreeMem(Res, SizeOf(Res^));
    Func := nil;
    FreeLibrary(H);
  end;

end;

function TPinPad.ReadTrack3: string;
var
  H: THandle;
  Func: TReadCardTrack3;
  Res: Pchar;
  Last4: Pchar;
  Hash: Pchar;
begin
  GetMem(Res, 255);
  GetMem(Last4, 4);
  GetMem(Hash, 255);

  H := LoadLibrary(Pchar(LibName));

  if H <= 0 then
  begin
    raise TPinpadException.Create(Format('Не могу загрузить %s', [LibName]));
    Exit;
  end;

  try
    @Func := GetProcAddress(H, Pchar('_ReadCardTrack3'));

    if not Assigned(Func) then
      raise TPinpadException.Create
        ('Функция _ReadCardTrack3 не найдена в pilot_nt.dll');

    try
      FLastError := Func(Last4, Hash, Res);
      Result := PAnsiChar(Res);
      FCardID := PAnsiChar(Last4);
    except
      on E: Exception do
        RaiseLastOSError;
    end;

  finally
    FreeMem(Res, SizeOf(Res^));
    FreeMem(Last4, SizeOf(Last4^));
    FreeMem(Hash, SizeOf(Hash^));
    Func := nil;
    FreeLibrary(H);
  end;
end;

function TPinPad.TryReturn(Amount: Double): boolean;
begin
  Result := (CardAuth7(Amount, OP_RETURN) = 0) and (SuspendTrx = 0);
end;

function TPinPad.RollBackTrx: integer;
var
  H: THandle;
  Func: TRollBackTrx;
begin
  H := LoadLibrary(Pchar(LibName));

  if H <= 0 then
  begin
    raise TPinpadException.Create(Format('Не могу загрузить %s', [LibName]));
    Exit;
  end;

  try
    @Func := GetProcAddress(H, Pchar('_RollbackTrx'));

    if not Assigned(Func) then
      raise TPinpadException.Create
        ('Функция _RollbackTrx не найдена в pilot_nt.dll');

    try
      Result := Func(FAuthAnswer.Amount, PAnsiString(AnsiString(FAuthCode)));
      FLastError := Result;
      FLastErrorMessage := GetMessageText(Result);
    except
      on E: Exception do
        RaiseLastOSError;
    end;

  finally
    Func := nil;
    FreeLibrary(H);
  end;

end;

// False - Контрольная лента, True - Сводный чек
function TPinPad.SberShift(IsDetailed: boolean = False): integer;
var
  H: THandle;
  Func: TGetStatistics;
begin
  H := LoadLibrary(Pchar(LibName));
  if H <= 0 then
  begin
    raise TPinpadException.Create(Format('Не могу загрузить %s', [LibName]));
    Exit;
  end;

  ClearBuffers;

  case IsDetailed of
    True:
      FAuthAnswer.TType := 1;
    False:
      FAuthAnswer.TType := 0;
  end;

  try
    @Func := GetProcAddress(H, Pchar('_get_statistics'));

    if not Assigned(Func) then
      raise TPinpadException.Create
        ('Функция _get_statistics не найдена в pilot_nt.dll');

    try
      Result := Func(@FAuthAnswer);
      FLastErrorMessage := PAnsiChar(@FAuthAnswer.AMessage);
      FCheque := PAnsiChar(FAuthAnswer.Check);
      FLastError := Result;
    except
      on E: Exception do
        RaiseLastOSError;
    end;

  finally
    Func := nil;
    FreeLibrary(H);
  end;
end;

function TPinPad.ServiceMenu: integer;
var
  H: THandle;
  Func: TServiceMenu;
begin
  ClearBuffers;

  H := LoadLibrary(Pchar(LibName));

  if H <= 0 then
  begin
    raise TPinpadException.Create(Format('Не могу загрузить %s', [LibName]));
    Exit;
  end;

  try
    @Func := GetProcAddress(H, Pchar('_ServiceMenu'));

    if not Assigned(Func) then
      raise TPinpadException.Create
        ('Функция _ServiceMenu не найдена в pilot_nt.dll');

    try
      Result := Func(@FAuthAnswer);
      FCheque := PAnsiChar(FAuthAnswer.Check);
      FLastError := Result;
    except
      on E: Exception do
        RaiseLastOSError;
    end;
  finally
    Func := nil;
    FreeLibrary(H);
  end;
end;

function TPinPad.SetGUIHandles(ATextHandle, AEditHandle: HWND): integer;
var
  H: THandle;
  Func: TSetGUIHandles;
begin
  H := LoadLibrary(Pchar(LibName));
  if H <= 0 then
  begin
    raise TPinpadException.Create(Format('Не могу загрузить %s', [LibName]));
    Exit;
  end;

  try
    @Func := GetProcAddress(H, Pchar('_SetGUIHandles'));

    if NOT Assigned(Func) then
      raise TPinpadException.Create
        ('Функция _SetGUIHandles не найдена в pilot_nt.dll');

    try
      Result := Func(ATextHandle, AEditHandle);
    except
      on E: Exception do
        RaiseLastOSError;
    end;

  finally
    Func := nil;
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
    raise TPinpadException.Create(Format('Не могу загрузить %s', [LibName]));
    Exit;
  end;

  try
    @Func := GetProcAddress(H, Pchar('_SuspendTrx'));

    if not Assigned(Func) then
      raise TPinpadException.Create
        ('Функция _SuspendTrx не найдена в pilot_nt.dll');

    try
      Result := Func(FAuthAnswer.Amount, PAnsiString(AnsiString(FAuthCode)));
      FLastError := Result;
      FLastErrorMessage := GetMessageText(Result);
    except
      on E: Exception do;
    end;

  finally
    Func := nil;
    FreeLibrary(H);
  end;

end;

function TPinPad.TestPinpad: boolean;
var
  H: THandle;
  Func: TTestPinPad;
begin
  Result := False;

  try
    H := LoadLibrary(Pchar(LibName));
    if H <= 0 then
    begin
      raise TPinpadException.Create(Format('Не могу загрузить %s', [LibName]));
      Exit;
    end;

    @Func := GetProcAddress(H, Pchar('_TestPinpad'));
    try
      FLastError := Func;
      Result := FLastError = 0;
    except
      on E: Exception do
        RaiseLastOSError;
    end;

  finally
    Func := nil;
    FreeLibrary(H);
  end;
end;

end.
