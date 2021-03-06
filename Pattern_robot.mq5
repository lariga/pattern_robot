//+------------------------------------------------------------------+
//|                                                      Lari$$a.mq5 |
//|                                                             Azat |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Azat"
#property link      ""
#property version   "1.00"

// входные параметры
input double MaxPosition = 100000.0; //максимальная позиция 
input double   MaxLoss = 2000.0; //максимальный убыток
input int   MaxLossCount = 5; //максимальное кол-во убыточных сделок
input double   Trailing = 0; //уровень трейлинг-стопа 
// файл с паттернами
input string f = "MA.csv";

// todo bug устранить утечку памяти
// todo реализовать проверку лимитов
// todo реализовать лимит входов

// todo реализовать усреднение -- может не нужно?
// todo реализовать защиту
// todo реализовать трейлинг

// todo для управления рисками прикрутить объект класса CExpertMoney 
// todo для взаимодействия с внешним миром использовать WebRequest - можно передавать различные данные, включая данные паттернов, и самое главное новости !!!

// todo перенести паттерны на веб-сервис
// todo веб-сервис написать на питоне
// todo реализовать сервис по парсингу и анализу новостей
// todo реализовать торгового робота по арбитражу
// todo реализовать возможность анализа условий по базовому активу
// todo реализвовать неограниченное количество условий
// todo автоматизировать перемещение файла в песочницу

// подключим торговый класс CTrade и объявим переменную этого типа
#include <Trade\Trade.mqh>
#include <Patterns.mqh>

// начало работы
datetime start_date;


//+------------------------------------------------------------------+
//| Инициализация                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    // торговые запросы будем отправлять в асинхронном режиме с помощью функции OrderSendAsync()
    trade.SetAsyncMode(true);

    #ifdef !DEBUG
        // проверим разрешение на автотрейдинг
        if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
            Alert("Автотрейдинг в терминале запрещен, эксперт будет выгружен.");
            ExpertRemove();
            return(-1);
        }
   
        // можно ли торговать на данном счете 
        if (!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) {
            Alert("Торговля на данном счете запрещена");
            ExpertRemove();
            return(-2);
        }
    #endif;  

    // запомним время запуска эксперта
    start_date = TimeCurrent();
    
    // загрузим все паттерны
    if (LoadPatterns())
        CheckPatterns();

    return(INIT_SUCCEEDED);
} // OnInit()


//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // уничтожим объекты для паттернов
    for (int i = 0; i < ArraySize(patterns); i++)
        delete patterns[i];
} // OnDeinit()
  
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // обработка тика для массива баров
    Rates::Tick();
    
    for (int i = 0; i < ArraySize(patterns); i++)
        patterns[i].Tick();
} // OnTick()
  
  
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
{
    CPositionInfo  myposition;
    int size = ArraySize(patterns);
    
    // пробежимся по всем открытым позициям и обновим позицию в паттерне
    for (int i = 0; i < PositionsTotal(); i++)
        if (myposition.Select(PositionGetSymbol(i))) {
            string comment;
            myposition.InfoString(POSITION_COMMENT, comment);        
            for (int j = 0; j < size; j++)
                if ("[PATT_" + patterns[j].Code + "]" == comment)
                    patterns[j].RefreshPosition(true);
        }
      
    // пробежимся по всем паттернам без позиций и обновим позицию в паттерне
    for (int j = 0; j < size; j++)
        if (!myposition.Select(patterns[j].symbol) && patterns[j].Position != NULL)
            patterns[j].RefreshPosition(false);         
} // OnTrade()


//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
{
    double ret = 0.0;

    return(ret);
}  // OnTester()


// Загрузка паттернов из файла
bool LoadPatterns()
{
    ResetLastError();

    int file_handle = FileOpen(f, FILE_READ|FILE_CSV|FILE_ANSI, ';');
    
    if (file_handle != INVALID_HANDLE) {
        Pattern *pattern; //текущий паттерн
        string pattern_name; //имя паттерна
        string pattern_code; //код паттерна
        int patt_count = 0; //кол-во паттернов
        bool is_enter_cond = false;
        bool is_exit_cond = false;
        bool load_pattern = false;
        
        while (!FileIsEnding(file_handle)) {
            string str = FileReadString(file_handle);
            
            if (str == "Паттерн:") {
                is_enter_cond = false;
                is_exit_cond = false;
                pattern_code = FileReadString(file_handle); // считаем код
                pattern_name = FileReadString(file_handle); // считаем имя
                if ((FileReadString(file_handle) == "Включен") || (FileReadString(file_handle)=="Включен")) {
                    patt_count++; // увеличим счетчик паттернов
                    pattern = new Pattern(pattern_code,pattern_name); //создадим паттерн
                    debug("Загружаем паттерн: " + pattern_name);
                    ArrayResize(patterns,patt_count);
                    patterns[patt_count-1] = pattern;
                    pattern.Enabled = true;
                    load_pattern = true;
                } else 
                    load_pattern = false;
            }
    
            if (load_pattern) {
                if (str == "Время работы:") {
                   pattern.TimeConditions[0] = FileReadString(file_handle);
                   pattern.TimeConditions[1] = FileReadString(file_handle);
                   pattern.TimeConditions[2] = FileReadString(file_handle);
                } else if (str == "Направление:") {
                    str = FileReadString(file_handle);
                    if (str == "Купить") {
                        pattern.IsBuy = true;
                        debug("Паттерн на покупку");
                    } else if (str == "Продать") {
                        pattern.IsBuy = false;
                        debug("Паттерн на продажу");
                    } else {
                        Print("Неверное описание входа: ",str);
                        pattern.Enabled = false;
                    }
                } else if (str == "Объем:") {
                    pattern.Volume = StringToInteger(FileReadString(file_handle));
                    debug("Объем: " + IntegerToString(pattern.Volume));
                } else if (str == "Цена:") {
                    pattern.SetPrice(FileReadString(file_handle));
                } else if (str == "Макс. отклонение:") {
                    pattern.Deviation = (int)StringToInteger(FileReadString(file_handle));
                    debug("Максимальное отклонение: " + IntegerToString(pattern.Deviation)); 
                } else if (str == "Лимит входов:") {
                    pattern.MaxEntries = (int)StringToInteger(FileReadString(file_handle));
                    debug("Лимит входов: " + IntegerToString(pattern.MaxEntries));
                } else if (str == "Стоп-лосс:") {
                    pattern.SetSl(FileReadString(file_handle));
                    is_exit_cond = false;
                } else if (str == "Тейк-профит:") {
                    pattern.SetTp(FileReadString(file_handle));
                } else if (str == "Защита:") {
                    pattern.SetProtect(FileReadString(file_handle));
                } else if (str == "Трейлинг:") {
                    pattern.SetTrailing(FileReadString(file_handle));
                } else if (str == "Усреднение:") {
                    pattern.SetAveraging(FileReadString(file_handle));
                    pattern.SetAveraging(FileReadString(file_handle));
                    pattern.SetAveraging(FileReadString(file_handle));
                    if (pattern.Enabled)
                        debug("Загрузили паттерн.");
                    else 
                        debug("Паттерн выключен.");
                } else if (str == "Условия входа:") {
                    is_enter_cond = true;
                    str = FileReadString(file_handle);
                } else if (str == "Условия выхода:") {
                    is_enter_cond = false;
                    is_exit_cond = true;
                    str = FileReadString(file_handle);
                } else if (is_enter_cond) {
                    if ((str != "")&&(StringSubstr(str, 0, 1) != "#")) {
                        pattern.AddEnterCondition(str);
                        debug("Загрузили условие: " + str);
                    }
                } 
                
                if (is_exit_cond) {
                    if ((str != "") && (StringSubstr(str, 0, 1) != "#")) {
                        pattern.AddExitCondition(str);
                        debug("Загрузили условие: " + str);
                    }
                }              
            }
        }
    
        // закрываем файл
        FileClose(file_handle);
    } else {
        Print("Ошибка открытия файла с паттернами: ", GetLastError());
        return(false);
    }
    
    Print("Паттерны загружены");
    return(true);
} // LoadPatterns()


// Проверка паттернов
bool CheckPatterns()
{
    int size = ArraySize(patterns);
    for (int i = 0; i < size; i++) {
        patterns[i].Validate();
    }

    Print("Паттерны проверены");
    return(true);
} // CheckPatterns()
