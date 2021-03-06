//+------------------------------------------------------------------+
//|                                                     Patterns.mqh |
//|                                                             Azat |
//|                                                                  |
//| Особенности входа в позицию:                                     |
//| 1. Если при входе в позицию уже существует открытая позиция по   |
//| тому же инструменту в том же направлении, то новая позиция не    |
//| открывается.                                                     |
//| 2. Если при входе в позицию уже существует открытая позиция по   |
//| тому же инструменту в противоположном направлении, то существую- |
//| щая позиция сначала закрывается, а затем открывается новая.      |
//| 3. При входе в позицию, все остальные паттерны из той же группы  |
//| автоматически отключаются.                                       |
//| 4. При входе в позицию все существующие ордера снимаются.        |
//|                                                                  |
//+------------------------------------------------------------------+

#property copyright "Azat"
#property link      ""
#property version   "1.00"

#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Conditions.mqh>

int err_code;  //код ошибки
CTrade trade;


//+------------------------------------------------------------------+
//| Класс для описания позиции                                      |
//+------------------------------------------------------------------+
class PatternPosition
{
    public:
                 PatternPosition(); //конструктор
                ~PatternPosition(); //деструктор

                double            Price; //цена
                double            Protect; //цена защиты
                double            Sl; //уровень стоп-лосса
                double            Tp; //уровень тейк-профита
                double            Volume; //объем
                
                ulong             Avg1Order; // тикет ордера на усреднение
                ulong             Avg2Order; // тикет ордера на усреднение
                ulong             Avg3Order; // тикет ордера на усреднение    
                ulong             ProtectOrder; // тикет защитного ордера                                          
  };
  
// конструктор     
PatternPosition::PatternPosition()
{
}
  
// деструктор     
PatternPosition::~PatternPosition()
{
}
  
//+------------------------------------------------------------------+
//| Класс для описания паттерна                                      |
//+------------------------------------------------------------------+
class Pattern
{
    private:
                bool              CheckTime();              // проверить условия по времени запуска
                bool              CheckLimit(ulong vol);    // проверка лимитов
                bool              CheckEnterConditions();   // проверка условий входа 
                bool              CheckExitConditions();    // проверка условий выхода                                                          
                Value            *Price;                    // цена входа                    
                Value            *Sl;                       // уровень Stop Loss 
                Value            *Tp;                       // уровень Take Profit    
                Value            *Trailing;                 // трейлинг
                Value            *Protect;                  // уровень Защиты
                Value            *Averaging[3];             // уровни усреднения
                long              prevTickVolume;           // объем предыдущего тика
                bool              prevTickPassed;           // предыдущий тик пропустили
                datetime          timeOpen;                 // время последнего входа
                ENUM_TIMEFRAMES   tf;                       // рабочий период паттерна
                void              UpdateTf(ENUM_TIMEFRAMES val); // обновить тайм-фрейм

    public:
                 Pattern(string code, string name, string symb = "");   //конструктор
                ~Pattern();                                             //деструктор
                    
                string            Code;                     //код паттерна
                string            symbol;                   //инструмент
                Condition        *EnterConditions[];        //условия входа
                Condition        *ExitConditions[];         //условия выхода
                string            TimeConditions[3];        //условия работы по времени
                string            Name;                     //наименование паттерна
                bool              Enabled;                  //включен/выключен
                bool              Validated;                //проверен                    
                bool              EveryTick;                //анализ текущего бара
                bool              IsBuy;                    //купить/продать
                ulong             Volume;                   //объем входа
                int               MaxEntries;               //максимальное количество входов     
                int               Deviation;                //максимальное отклонение              
                PatternPosition *Position;

                void              SetPrice(string val);     // установить цену входа
                void              SetSl(string val);        // установить уровень Stop Loss 
                void              SetTp(string val);        // установить уровень Take Profit  
                void              SetTrailing(string val);  // установить Трейлинг 
                void              SetProtect(string val);   // установить уровень защиты
                void              SetAveraging(string val); // установить уровень усреднения                     
                void              Validate();               //завалидировать   
                void              OpenPosition(ulong vol);  //открыть позицию 
                void              CheckForOpenPosition();   //проверить и открыть позицию 
                void              ClosePosition();          //закрыть позицию
                void              CloseOrders();            //закрыть ордера
                void              CheckForClosePosition();  //проверить и закрыть позицию
                void              RefreshPosition(bool open);       //обновить информацию о позиции
                void              AddEnterCondition(string val);    //добавить условие входа
                void              AddExitCondition(string val);     //добавить условие выхода
                void              Tick();                           //обработчик события OnTick             

}; // class Pattern


// массив с паттернами
Pattern *patterns[];


// конструктор     
Pattern::Pattern(string code, string name, string symb = "")
{
    Name = name;
    Code = code;
    Enabled = false;
    Validated = false;
    EveryTick = false;
    prevTickVolume = 100000000000;
    prevTickPassed = false;
    timeOpen = 0;
    tf = NULL;

    if (symb == "")
        symbol = Symbol();
    else
        symbol = symb;
        
    if (!GlobalVariableCheck("PATT_" + Code + "_LOSS"))
        GlobalVariableSet("PATT_" + Code + "_LOSS", 0);
        
    if (!GlobalVariableCheck("PATT_" + Code + "_PROFIT"))
        GlobalVariableSet("PATT_" + Code + "_PROFIT", 0);
        
    if (!GlobalVariableCheck("PATT_" + Code + "_LOSS_COUNT"))
        GlobalVariableSet("PATT_" + Code + "_LOSS_COUNT", 0);
        
    if (!GlobalVariableCheck("PATT_" + Code + "_PROFIT_COUNT"))
        GlobalVariableSet("PATT_" + Code + "_PROFIT_COUNT", 0);
        
    if (!GlobalVariableCheck("TOTAL_LOSS"))
        GlobalVariableSet("TOTAL_LOSS", 0);
        
    if (!GlobalVariableCheck("TOTAL_PROFIT"))
        GlobalVariableSet("TOTAL_PROFIT", 0);
}
  
  
// установить цену входа
void Pattern::SetPrice(string val)
{
    StringReplace(val, " ", "");
    Price = new Value(val, symbol);
    debug("Цена: " + val);
}
  
  
// установить уровень Stop Loss
void Pattern::SetSl(string val)
{
    StringReplace(val, " ", "");
    Sl = new Value(val, symbol);
    debug("Стоп-лосс: " + val);
}
  
  
// установить уровень Take Profit
void Pattern::SetTp(string val)
{
    StringReplace(val, " ", "");
    Tp = new Value(val, symbol);
    debug("Тейк-профит: " + val);
}
  
  
// установить Трейлинг 
void Pattern::SetTrailing(string val)
{
    StringReplace(val, " ", "");
    Trailing = new Value(val, symbol);
    debug("Трейлинг: " + val);
}
  
// установить уровень Защиты 
void Pattern::SetProtect(string val)
{
    StringReplace(val, " ", "");
    Protect = new Value(val, symbol);
    debug("Защита: " + val);
}
  
// установить уровень Защиты 
void Pattern::SetAveraging(string val)
{
    StringReplace(val, " ", "");
    
    if (Averaging[0] == NULL) {
        Averaging[0] = new Value(val, symbol);
        debug("Усреднение 1: " + val);
    } 
    
    if (Averaging[1] == NULL) {
        Averaging[1] = new Value(val, symbol);
        debug("Усреднение 2: " + val);
    } 
    
    if (Averaging[2] == NULL) {
        Averaging[2] = new Value(val, symbol);
        debug("Усреднение 3: " + val);
    }
}


//добавить условие входа
void Pattern::AddEnterCondition(string val)
{
    int conditions_count = ArraySize(EnterConditions);
    ArrayResize(EnterConditions, conditions_count + 1, 10);
    EnterConditions[conditions_count] = new Condition(val, symbol);
    debug("Загрузили условие входа: " + val);
}


//добавить условие входа
void Pattern::AddExitCondition(string val)
{
    int conditions_count = ArraySize(ExitConditions);
    ArrayResize(ExitConditions, conditions_count + 1, 10);
    ExitConditions[conditions_count] = new Condition(val, symbol);
    debug("Загрузили условие выхода: " + val);
}


//обновить тайм-фрейм
void Pattern::UpdateTf(ENUM_TIMEFRAMES val)
{
    if (PeriodSeconds(val) < PeriodSeconds(tf) || tf == NULL)
        tf = val;
}


// завалидировать                              
void Pattern::Validate()
{
    if (Enabled) {
        //проверка символа
        ResetLastError();
        SymbolInfoString(symbol, SYMBOL_DESCRIPTION);
        err_code = GetLastError();
        
        if (err_code != 0) {
            Print("Ошибка проверки символа ",symbol + ". Паттерн будет выключен");
            Enabled = false;
            return;
        }

        //проверка условий входа
        int size = ArraySize(EnterConditions);
        
        for (int i = 0; i < size; i++) {
            StringReplace(EnterConditions[i].Str, " ", "");
            
            if (!EnterConditions[i].Parse()) {
                Print("Ошибка проверки условия ", EnterConditions[i].Str + ". Паттерн будет выключен");
                Enabled = false;
                return;
            }

            int pos = StringFind(EnterConditions[i].Str, "(0)");
            
            if (pos >= 0)
                EveryTick = true;

            UpdateTf(EnterConditions[i].part1.Tf);
            UpdateTf(EnterConditions[i].part2.Tf);
        }

        //проверка условий выхода
        size = ArraySize(ExitConditions);
      
        for (int i = 0; i < size; i++) {
            StringReplace(ExitConditions[i].Str, " ", "");
         
            if (!ExitConditions[i].Parse()) {
                Print("Ошибка проверки условия ", ExitConditions[i].Str + ". Паттерн будет выключен");
                Enabled = false;
                return;
            }

            int pos = StringFind(ExitConditions[i].Str, "(0)");
            
            if (pos >= 0)
                EveryTick = true;

            UpdateTf(ExitConditions[i].part1.Tf);
            UpdateTf(ExitConditions[i].part2.Tf);
        }
        
        //проверка цены
        if (!Price.Check()) {
            Print("Ошибка проверки цены ", Price.Str + ". Паттерн будет выключен");
            Enabled = false;
            return;
        }

        //проверка стоп-лосса
        if (!Sl.Check()) {
            Print("Ошибка проверки стоп-лосса ", Sl.Str + ". Паттерн будет выключен");
            Enabled = false;
            return;
        }

        //проверка тейк-профита
        if (!Tp.Check()) {
            Print("Ошибка проверки тейк-профита ", Tp.Str + ". Паттерн будет выключен");
            Enabled = false;
            return;
        }
      
        UpdateTf(Price.Tf);
        UpdateTf(Sl.Tf);
        UpdateTf(Tp.Tf);
        debug("Рабочий тайм-фрейм паттерна: " + EnumToString(tf));
  
        Validated = true;
    }
}


// проверить условия по времени запуска
bool Pattern::CheckTime()
{
    bool is_ok = false;
    datetime now = TimeLocal();
    string date = TimeToString(now, TIME_DATE);
    
    int size = ArraySize(TimeConditions);
    
    for (int i = 0; i < size; i++) {
        string str = TimeConditions[i];
        int pos = StringFind(str, "-");
      
        if (pos > 0) {
            datetime time1 = StringToTime(date + " " + StringSubstr(str, 0, pos));
            datetime time2 = StringToTime(date + " " + StringSubstr(str, pos + 1));

            if ((time1 <= now && now <= time2) || 
                    (time1 > time2 && (time1 <= now || now <= time2))) {
                is_ok = true;
                // Print("Проверка времени пройдена.");
                break;
            }
        }
    }
 
    return is_ok;
}


// проверить лимиты по позиции/убытку                            
bool Pattern::CheckLimit(ulong vol)
{    
    //todo   Реализовать
    return true;
}


// проверка условий входа                           
bool Pattern::CheckEnterConditions()
{
    bool all_conds = true;
    bool need_calc = true;
    int size = ArraySize(EnterConditions);
    
    for (int i = 0; i < size; i++) {  
        //Если условие OR
        if (EnterConditions[i].Str == "OR") {
            if(i != 0 && all_conds) 
                break; //если все условия до OR выполнены, то выходим
                
            all_conds = (i != size - 1); //если после OR нет условия, то считаем его невыполненным
            need_calc = true;
        } else {
            bool calc = false;
            
            if (need_calc) { 
                calc = EnterConditions[i].Calc();
                all_conds = all_conds && calc && EnterConditions[i].rates_is_ok;
             
                if (!calc)
                    need_calc = false;
            }          
        }   
    }
    
    return all_conds;
}
 
 
//проверка условий выхода                           
bool Pattern::CheckExitConditions()
{
    bool all_conds = true;
    bool need_calc = true;
    int size = ArraySize(ExitConditions);
    
    for (int i = 0; i < size; i++) {  
        // если условие OR
        if (ExitConditions[i].Str == "OR") {
            if (i != 0 && all_conds)
                break; //если все условия до OR выполнены, то выходим
            
            all_conds = (i != size - 1); //если после OR нет условия, то считаем его невыполненным
            need_calc = true;
        } else {
            bool calc = false;
            
            if (need_calc) { 
                calc = ExitConditions[i].Calc();
                all_conds = all_conds && calc;
                
                if (!calc) 
                    need_calc = false;
            }          
        }   
    }
     
    return all_conds;
}


// проверить и войти в позицию 
void Pattern::CheckForOpenPosition()
{
    if (CheckEnterConditions()) {
        ulong vol = Volume;
        debug("Все условия для инструмента " + symbol + " выполнены.");
        
        // отменим ордера
        CloseOrders();
        
        // если позиция уже открыта
        if (PositionSelect(symbol)) {
            // если открыта в другую сторону, то закроем
            if (((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) && (!IsBuy))
                    || ((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) && IsBuy)) {
                debug("Закрываем текущую позицию.");
                trade.PositionClose(symbol, Deviation);
            } else { // если открыта в нашу сторону, то определим объем
                vol = (ulong)PositionGetDouble(POSITION_VOLUME);
                
                if (vol >= Volume)
                    vol = 0;
                else
                    vol = (ulong)MathRound(Volume - vol);
            }
        }
        
        // todo реализовать проверку Deviation при входе
    
        if ((vol >= 1) && (CheckLimit(vol))) {
            debug("Входим в позицию.");
            OpenPosition(vol);
        }
    }
}
 
 
// войти в позицию 
void Pattern::OpenPosition(ulong vol)
{
    double price, tp, sl;
    string comment = "[PATT_" + Code + "]";
    ENUM_ORDER_TYPE order_type;
    
    if (vol > 0) {
        MqlTick tick;
        
        if (SymbolInfoTick(symbol, tick))
            Value::SetValue(symbol, "PRICE", IsBuy ? tick.ask : tick.bid);
        
        price = Price.CalcPrice();
        sl = Sl.CalcPrice();
        tp = Tp.CalcPrice();
        
        if (price == 0) {
            order_type = IsBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
            price = Value::GetValue(symbol, "PRICE");
        } else
            order_type = IsBuy ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
        
        Value::ClearValue(symbol, "PRICE");
        
        debug("Открываем позицию.ПАТТЕРН: " + Name);;
        debug("Тип ордера:" + EnumToString(order_type));
        debug("Цена:" + (string)price + ". Объем:" + (string)vol);
        debug("Стоп-лосс:" + (string)sl);
        debug("Таке-профит:" + (string)tp);

        trade.PositionOpen(
                             symbol,
                             order_type,
                             vol,
                             price,
                             sl,
                             tp,
                             comment
                           );
                                        
        timeOpen = TimeCurrent(); // запоминаем последнее время входа
        MqlTradeRequest request;
        MqlTradeResult result;
        string str;
        trade.Request(request);
        trade.Result(result);
        trade.FormatRequest(str, request);
        debug("Параметры запроса:" + str);
        trade.FormatRequestResult(str, request, result);
        debug("Результат запроса:" + str);
        debug("Код возрата:" + (string)trade.ResultRetcode());
        debug("Тикет сделки:" + (string)trade.ResultDeal());                   
    }
} // Pattern::OpenPosition()


// проверить и закрыть позицию 
void Pattern::CheckForClosePosition()
{
    if (CheckExitConditions()) {
        debug("Все условия для инструмента " + symbol + " выполнены.");      
        trade.PositionClose(symbol, Deviation);
    }
}


// закрыть позицию 
void Pattern::ClosePosition()
{    
    // сначала ордера 
    CloseOrders();
    
    // если позиция  открыта
    if (PositionSelect(symbol)) { 
        debug("Закрываем текущую позицию.");
        
        trade.PositionClose(
                              symbol,
                              Deviation
                           );
        
        MqlTradeRequest request;
        MqlTradeResult result;
        string str;
        trade.Request(request);
        trade.Result(result);
        trade.FormatRequest(str, request);
        debug("Параметры запроса:" + str);
        trade.FormatRequestResult(str, request, result);
        debug("Результат запроса:" + str);
        debug("Код возрата:" + (string)trade.ResultRetcode());
        debug("Тикет сделки:" + (string)trade.ResultDeal());
    }         
}  


// Закрыть ордера 
void Pattern::CloseOrders()
{
    debug("Закрываем ордера:");
    
    COrderInfo myorder;
    int ord_total = OrdersTotal();
    
    for (int i = 0; i < ord_total; i++)
        if (OrderSelect(OrderGetTicket(i))) {
            ulong ticket = OrderGetTicket(i);
            
            if (myorder.Symbol() == symbol) {
                MqlTradeResult result = {0};
                MqlTradeRequest request = {0};
                request.order = ticket;
                request.action = TRADE_ACTION_REMOVE;
                debug("Отменяем ордер:" + (string)ticket);
                
                if (!OrderSend(request, result))
                    debug("Ошибка отмены. Код возрата:" + (string)result.retcode);
            }
        }
}  


//обновить информацию о позиции
void Pattern::RefreshPosition(bool open)   
{
    CPositionInfo pos;
    debug("Обновим информацию о позиции.");
    int size = ArraySize(patterns);
    
    // если позиция открыта
    if (open) {   
        if (Position == NULL)
            Position = new PatternPosition();
        
        Position.Price = pos.PriceOpen(); 
        Position.Volume = pos.Volume();
        Position.Sl = pos.StopLoss(); 
        Position.Tp = pos.TakeProfit(); 
        
        Value::SetValue(symbol, "OPEN_PRICE", Position.Price);
        Value::SetValue(symbol, "OPEN_VOL", Position.Volume);
        Value::SetValue(symbol, "STOP", Position.Sl);
        Value::SetValue(symbol, "TAKE", Position.Tp);
        Value::SetValue(symbol, "RISK", MathAbs(Position.Price - Position.Tp));
        
        //Update
            
        // выключаем все остальные паттерны с этим же кодом или направлением
        for (int i = 0; i < size; i++)
            if ((patterns[i].Code == Code || patterns[i].IsBuy == IsBuy) && patterns[i].Enabled && patterns[i] != GetPointer(this))
                patterns[i].Enabled = false;

        if (size > 1)
            debug("Выключили остальные паттерны");   
    } else {    // если позиций нет
        if(Position != NULL) 
            delete Position; 
      
        Value::SetValue(symbol, "OPEN_PRICE", NULL);
        Value::SetValue(symbol, "OPEN_VOL", NULL);
        Value::SetValue(symbol, "STOP", NULL);
        Value::SetValue(symbol, "TAKE", NULL);
      
        // включаем все остальные паттерны с этим же кодом или направлением
        for(int i = 0; i < size; i++)
            if((patterns[i].Code == Code || patterns[i].IsBuy == IsBuy) && !patterns[i].Enabled && patterns[i].Validated && patterns[i] != GetPointer(this))
                patterns[i].Enabled = true;
             
        if (size > 1)
            debug("Включили остальные паттерны");   
    }
} // Pattern::RefreshPosition()


void Pattern::Tick()
{
    if (Enabled && !Validated)
        Validate();
    
    Rates *rates = Rates::GetRates(symbol, tf);
    if (rates.is_ok)
        prevTickPassed = false;
    else {
        prevTickPassed = true;
        return;   
    }
    
    if (Enabled && CheckTime() && rates.arr[0].time > timeOpen) {
        if (!EveryTick && !prevTickPassed) {
            if (rates.arr[0].tick_volume >= prevTickVolume) {
                prevTickVolume = rates.arr[0].tick_volume;
                return;
            }
    
            prevTickVolume = 0;
        }
    
        CheckForOpenPosition();
        //CheckForClosePosition();
    }
} // Pattern::Tick()


// деструктор   
Pattern::~Pattern()
{
    int size = ArraySize(EnterConditions);
    
    for(int i = 0; i < size; i++)
        delete EnterConditions[i];

    size = ArraySize(ExitConditions);
    
    for(int i = 0; i < size; i++)
        delete ExitConditions[i];
 
    size = ArraySize(Rates::rates);
    
    for(int i = 0; i < size; i++)
        delete Rates::rates[i];
}
