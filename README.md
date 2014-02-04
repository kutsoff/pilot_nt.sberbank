# Sberbank pilot_nt.dll DELPHI wrapper

Made for Delphi 2010 or higher (Unicode). Maybe it works in 2009, but not tested.

## Usage:

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
  end;    
  finally
    PinPad.Free;
  end
  else
    raise Exception.create('PinPad was not found');

end;
</code></pre>
