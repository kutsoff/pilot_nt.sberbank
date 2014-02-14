# Sberbank pilot_nt.dll DELPHI wrapper

Made for Delphi 2010 or higher (Unicode). Maybe it works in 2009, but not tested.

## Usage:

### Пример снятия сверки итогов(закрытие дня). Example of usage CloseDay function

<pre><code>// Пример снятия сверки итогов(закрытие дня)

var
  PinPad: TPinPad;
begin
  try
    PinPad := TPinPad.Create;
    if PinPad.TestPinPad then // Проверяем наличие пинпада
    begin
      if Pinpad.CloseDay = 0 then
        ShowMessage(PinPad.Cheque) // Показать сообщение с отчетом
      else
        raise Exception.Create('Error!');
    end
    else
      raise Exception.create('PinPad was not found');
  finally
    PinPad.Free;
  end;

end;
</code></pre>

### Пример проведения оплаты по карте. Example of payment usage

<pre><code> // Пример проведения оплаты по карте на сумму 100 руб 20 коп
var
  PinPad: TPinPad;
  ok: boolean;
begin
  try
    PinPad := TPinPad.Create;
    OK  := PinPad.CardAuth7(100.2, sberPayment) = 0;  // Авторизация карты
    if OK then
    begin
      OK := PinPad.SuspendTrx = 0;                    // Ставим транзакцию на паузу
        if OK then
          begin
            PinPad.CommitTrx;                         // Если оплата прошла, фиксируем транзакцию
            ShowMessage(PinPad.Cheque);               // и выводим сообщение с чеком-ответом от банка
          end
          else
          begin
            PinPad.RollBackTrx;                       // иначе отменяем транзакцию
            ShowMessage('Не удалось совершить оплату');
          end;
    end;
  finally
    PinPad.Free;
  end
end;
</pre></code>
