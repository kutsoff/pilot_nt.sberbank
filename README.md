pilot_nt.sberbank
=================

Sberbank pilot_nt.dll DELPHI wrapper

Made for Delphi 2010 or higher (Unicode). Maybe it works in 2009, but not tested.


Usage:
// Пример снятия сверки итогов(закрытие дня)

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
      raise error.Create('Error!');
  end;    
  finally
    PinPad.Free;
  end
    raise error.create('PinPad was not found');
  
end;
