//+------------------------------------------------------------------+
//|                                                   Conditions.mqh |
//|                                                             Azat |
//|                                             https://www.mql5.com |
//|                                                                  |
//| -допускаются операторы сравнения >,>=,<,<=,=,!=                  |
//| -допускается один оператор +,-,*,/ в каждой части                |
//| -допускается использовать определенные функции                   |
//| -после имени значения допускается указывать индекс бара в ()     |
//| -допускается указание тайм-фрейма в скобках [] в каждой части    |
//+------------------------------------------------------------------+

#property copyright "Azat"
#property link      ""

#define DEBUG  //режим отладки 
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Вывод отладочной информации                                      |
//+------------------------------------------------------------------+
void debug(string str)
{
   #ifdef DEBUG
      printf(__FUNCTION__+": " + str);
   #endif;
}

//описание уровня
struct Level
{
   string name; // имя
   int power; // сила
   bool is_support; // линия поддержки
   bool is_trend; // трендовая линия
   double value; //значение
};


//+------------------------------------------------------------------+
//| Класс для описания кеш-массива баров                                       |
//+------------------------------------------------------------------+
class Rates
{                                        
public:
           Rates();   //конструктор
           ~Rates();            //деструктор
           string symbol;       //символ
           ENUM_TIMEFRAMES tf;  //тайм-фрейм
           string indicator;    //индикатор 
           int parameter;   //параметер идикатора
           int handle;   //хендл идикатора
           MqlRates arr[];   //массив с данными баров
           double ind[];   //массив с индикаторными данными      

           static Rates *rates[]; //массив для хранения баров                  
           static Rates *GetRates(string symbol, ENUM_TIMEFRAMES tf, string indicator = "", int param = 0); //получить массив баров
           static Rates *GetRates(ENUM_TIMEFRAMES tf, string indicator = ""); //получить массив баров
           static void Tick(); //обработка тика 
           static datetime refresh_time; // время обработки
           static Level levels[];  //уровни поддержки-сопротивления
           static void AddLevel(string name, int power, bool is_support, bool is_trend, double value);  //добавить уровень
           
};

// инициализация статических свойств
Rates *Rates::rates[];
Level Rates::levels[];
datetime Rates::refresh_time = 0;

//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
Rates::Rates()
{  
   handle = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Деструктор                                                       |
//+------------------------------------------------------------------+
Rates::~Rates()
{
}

//+------------------------------------------------------------------+
//| обработка тика                                                   |
//+------------------------------------------------------------------+
static void Rates::Tick()
{
   int size = ArraySize(rates); 
   
   if(size != 0)
      for(int i=0;i<size;i++)
      { 
         int copied=CopyRates(rates[i].symbol,rates[i].tf,0,100,rates[i].arr);
         if(copied>0)
            ;//debug("Скопировано баров: " + IntegerToString(copied));
         else Print("Не удалось получить исторические данные по символу ",rates[i].symbol);    
         
         if (rates[i].handle!=INVALID_HANDLE)   
         {
            copied=CopyBuffer(rates[i].handle,0,0,100,rates[i].ind);
            if(copied>0)
               ;//debug("Скопировано баров: " + IntegerToString(copied));
            else Print("Не удалось получить индикаторные данные по символу ",rates[i].symbol);
         }                
      }
        
   //раз в 10 минут обновляем уровни поддержки и сопротивления
   if (TimeCurrent() - Rates::refresh_time > 600)   
   {
      Rates::refresh_time = TimeCurrent();
      ArrayResize(levels, 0);
      
      int lines = ObjectsTotal(0,0,OBJ_HLINE);
      int trends = ObjectsTotal(0,0,OBJ_TREND);
      
      for(int i=0;i<lines;i++)
      {
         string level_name = ObjectName(0,i,0,OBJ_HLINE);

         if(StringSubstr(level_name,0,4) == "SUP(")
         {
            int pos = StringFind(level_name,")");
            int power = (int)StringToInteger(StringSubstr(level_name, 4, pos - 4));
            double value = ObjectGetDouble(0, level_name, OBJPROP_PRICE);
            if (power > 0)
               AddLevel(level_name, power, true, false, value);
         }
         if(StringSubstr(level_name,0,4) == "RES(")
         {
            int pos = StringFind(level_name,")");
            int power = (int)StringToInteger(StringSubstr(level_name, 4, pos - 4));
            double value = ObjectGetDouble(0, level_name, OBJPROP_PRICE);
            if (power > 0)
               AddLevel(level_name, power, false, false, value);
         }   
         if(StringSubstr(level_name,0,7) == "SUPRES(")
         {
            int pos = StringFind(level_name,")");
            int power = (int)StringToInteger(StringSubstr(level_name, 7, pos - 7));
            double value = ObjectGetDouble(0, level_name, OBJPROP_PRICE);
            if (power > 0)
            {
               AddLevel(level_name, power, true, false, value);
               AddLevel(level_name, power, false, false, value);
            }
         }  
      }


      for(int i=0;i<trends;i++)
      {
         string level_name = ObjectName(0,i,0,OBJ_TREND);

         if(StringSubstr(level_name,0,4) == "SUP(")
         {
            int pos = StringFind(level_name,")");
            int power = (int)StringToInteger(StringSubstr(level_name, 4, pos - 4));
            if (power > 0)
               AddLevel(level_name, power, true, true, 0);
         }
         if(StringSubstr(level_name,0,4) == "RES(")
         {
            int pos = StringFind(level_name,")");
            int power = (int)StringToInteger(StringSubstr(level_name, 4, pos - 4));
            if (power > 0)
               AddLevel(level_name, power, false, true, 0);
         }   
         if(StringSubstr(level_name,0,7) == "SUPRES(")
         {
            int pos = StringFind(level_name,")");
            int power = (int)StringToInteger(StringSubstr(level_name, 7, pos - 7));
            if (power > 0)
            {
               AddLevel(level_name, power, true, true, 0);
               AddLevel(level_name, power, false, true, 0);
            }
         } 
      }
   }
}

//добавить уровень
static void Rates::AddLevel(string name, int power, bool is_support, bool is_trend, double value)
{
   int size = ArraySize(levels);
   ArrayResize(levels, size + 1);
   
   levels[size].name = name;
   levels[size].power = power;
   levels[size].is_support = is_support;
   levels[size].is_trend = is_trend;
   levels[size].value = value;
}

//+------------------------------------------------------------------+
//| получить массив баров                                            |
//+------------------------------------------------------------------+
static Rates *Rates::GetRates(string symbol, ENUM_TIMEFRAMES tf, string indicator = "", int param = 0)
{
   int size = ArraySize(rates); 
   
   if(size != 0)
      for(int i=0;i<size;i++)
         if((rates[i].symbol == symbol)&&(rates[i].tf == tf)&&(rates[i].indicator == indicator)&&(rates[i].parameter == param))
         { 
//            debug("Нашли готовые бары для символа: " + symbol + "  Тайм-фрейм: " + EnumToString(tf));  
            return rates[i];  //нашли массив - сразу вернем его     
         }   
   
   //если нет такого символа с таймфреймом, то создадим массив и получим бары
//   debug("Получаем бары для символа: " + symbol + "  Тайм-фрейм: " + EnumToString(tf));
   
   Rates *r = new Rates();
   r.symbol = symbol;
   r.tf = tf;
   r.indicator = indicator;
   r.parameter = param;
   ArrayResize(rates, size + 1, 10);
   rates[size] = r;  
   ArraySetAsSeries(r.arr, true);  
   
   int copied=CopyRates(symbol,tf,0,100,r.arr);
   if(copied>0)
      ;//debug("Скопировано баров: " + IntegerToString(copied));
   else Print("Не удалось получить исторические данные по символу ",symbol);
   
   if (indicator == "SMA")   
   {
      if(r.handle==INVALID_HANDLE)
      {
         ArraySetAsSeries(r.ind, true);
         r.handle = iMA(symbol, tf, param, 0, MODE_SMA, PRICE_CLOSE);
         if(r.handle==INVALID_HANDLE)
            Print("Не удалось создать индикатор SMA");
      }
   }   

   if (indicator == "EMA")   
   {
      if(r.handle==INVALID_HANDLE)
      {
         ArraySetAsSeries(r.ind, true);
         r.handle = iMA(symbol, tf, param, 0, MODE_EMA, PRICE_CLOSE);
         if(r.handle==INVALID_HANDLE)
            Print("Не удалось создать индикатор EMA");
      }
   }   

   if (indicator == "RSI")   
   {
      if(r.handle==INVALID_HANDLE)
      {
         ArraySetAsSeries(r.ind, true);
         r.handle = iRSI(symbol, tf, param, PRICE_CLOSE);
         if(r.handle==INVALID_HANDLE)
            Print("Не удалось создать индикатор RSI");
      }
   }  
   
   if (indicator == "ATR")   
   {
      if(r.handle==INVALID_HANDLE)
      {
         ArraySetAsSeries(r.ind, true);
         r.handle = iATR(symbol, tf, param);
         if(r.handle==INVALID_HANDLE)
            Print("Не удалось создать индикатор ATR");
      }
   }  
      
   if (indicator != "" && r.handle!=INVALID_HANDLE)   
   {
      copied=CopyBuffer(r.handle,0,0,100,r.ind);
      if(copied>0)
         ;//debug("Скопировано баров: " + IntegerToString(copied));
      else Print("Не удалось получить индикаторные данные по символу ",symbol);
   }
   
   return r;
}

//+------------------------------------------------------------------+
//| получить массив баров                                            |
//+------------------------------------------------------------------+
static Rates *Rates::GetRates(ENUM_TIMEFRAMES tf, string indicator = "")
{
   return GetRates(_Symbol, tf, indicator);
}


//сохраненные значения
struct save_value
{
   string symbol; //символ
   string name; // имя
   double value; //значение
};

//+------------------------------------------------------------------+
//| Класс для описания значения                                       |
//+------------------------------------------------------------------+

class Value
{
private:
                    double CalcPart(string val);   //вычислить часть значения
                    bool CheckPart(string val);  
                    string symbol;
                    static save_value saved_values[];                                                      
public:
                    Value(string val, string symb);   //конструктор
                    ~Value();  //деструктор
                    string Str;    //строка условия
                    ENUM_TIMEFRAMES Tf; //таймфрейм
                    double Last; //вычисленное значение
                    bool GetTf(); //заполнить тайм-фрейм из строки
                    bool Parse(); //симантический разбор
                    double Calc();  //вычислить значение
                    bool Check();
                    bool error_calc;
                    //извлечь значение
                    static double ReadValue(string symbol, string name);  
                    //сохранить значение
                    static void SaveValue(string symbol, string name, double value);  
                    //удалить значение
                    static void DelValue(string symbol, string name);                                      
};

save_value Value::saved_values[];

//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
Value::Value(string val, string symb)
{
   Str = val;
   symbol = symb;
   error_calc = false;
}

//+------------------------------------------------------------------+
//| Деструктор                                                       |
//+------------------------------------------------------------------+
Value::~Value()
{
}

//сохранить значение
static void Value::SaveValue(string symbol, string name, double value)
{ 
   int size = ArraySize(saved_values);
   ArrayResize(saved_values, size + 1);

   saved_values[size].symbol = symbol;   
   saved_values[size].name = name;
   saved_values[size].value = value;
}
   
//извлечь значение
static double Value::ReadValue(string symbol, string name)
{ 
   int size = ArraySize(saved_values); 

   for(int i = 0; i < size; i++)
     if(saved_values[i].name == name && saved_values[i].symbol == symbol) 
        return saved_values[i].value;
   
   return NULL;          
}

//извлечь значение
static void Value::DelValue(string symbol, string name)
{ 
   int size = ArraySize(saved_values); 

   for(int i = 0; i < size; i++)
     if(saved_values[i].name == name && saved_values[i].symbol == symbol) 
        saved_values[i].value = NULL;       
}
                    
 //получить тайм-фрейм из строки
bool Value::GetTf()
{
   Tf = NULL;
   
   int pos1 = StringFind(Str,"[");
   if (pos1 > -1)
   {
      int pos2 = StringFind(Str,"]");
      if (pos2 > pos1)
      {
         string val = StringSubstr(Str, pos1 + 1, pos2 - pos1 - 1);
         
         if (val == "M1")
            Tf = PERIOD_M1;
         if (val == "M2")
            Tf = PERIOD_M2;
         if (val == "M3")
            Tf = PERIOD_M3;
         if (val == "M4")
            Tf = PERIOD_M4;
         if (val == "M5")
            Tf = PERIOD_M5;   
         if (val == "M6")
            Tf = PERIOD_M6;
         if (val == "M10")
            Tf = PERIOD_M10;
         if (val == "M12")
            Tf = PERIOD_M12;
         if (val == "M15")
            Tf = PERIOD_M15;
         if (val == "M20")
            Tf = PERIOD_M20;         
         if (val == "M30")
            Tf = PERIOD_M30; 
         if (val == "H1")
            Tf = PERIOD_H1; 
          if (val == "H2")
            Tf = PERIOD_H2; 
          if (val == "H3")
            Tf = PERIOD_H3; 
          if (val == "H4")
            Tf = PERIOD_H4; 
          if (val == "H6")
            Tf = PERIOD_H6;
          if (val == "H8")
            Tf = PERIOD_H8; 
          if (val == "H12")
            Tf = PERIOD_H12; 
          if (val == "D1")
            Tf = PERIOD_D1; 
          if (val == "W1")
            Tf = PERIOD_W1; 
          if (val == "MN1")
            Tf = PERIOD_MN1; 
         
         if (Tf == NULL)
            debug("Не определен тайм-фрейм " + val + " в условии");
         else
            Str = StringSubstr(Str, 0, pos1) + StringSubstr(Str, pos2 + 1);   
      } 
      else 
         debug("Не найдена закрывающаяся скобка в условии");
   } else Tf = Period();
   
   return (Tf != NULL);
}

//вычисление часть значения
double Value::CalcPart(string val)
{
   int pos1, pos2, pos3, ind, param = 0;
   
   pos1 = StringFind(val,"(");
   if (pos1 >= 0)
   {
      pos2 = StringFind(val,")");
      
      if((pos2 >= 0)&&(pos2 > pos1))
      {
         string s = StringSubstr(val, pos1 + 1, pos2 - pos1 - 1);
         pos3 = StringFind(s,",");
         if (pos3 >= 0)
         {
            ind = (int)StringToInteger(StringSubstr(s, 0, pos3));
            param = (int)StringToInteger(StringSubstr(s, pos3 + 1));
         }
         else ind = (int)StringToInteger(s);
         
         if (val == "OPEN("+s+")")
         {
            Rates *rates = Rates::GetRates(symbol,Tf);
            return rates.arr[ind].open;
         }
         if (val == "CLOSE("+s+")")
         {
            Rates *rates = Rates::GetRates(symbol,Tf);
            return rates.arr[ind].close;
         }   
         if (val == "HIGH("+s+")")
         {
            Rates *rates = Rates::GetRates(symbol,Tf);
            return rates.arr[ind].high;
         } 
         if (val == "LOW("+s+")")
         {
            Rates *rates = Rates::GetRates(symbol,Tf);
            return rates.arr[ind].low;
         }  
         if (val == "VOLUME("+s+")")
         {
            Rates *rates = Rates::GetRates(symbol,Tf);
            return (double)rates.arr[ind].real_volume;
         }   
         if (val == "BODY("+s+")")
         {
            Rates *rates = Rates::GetRates(symbol,Tf);
            return MathAbs(rates.arr[ind].open - rates.arr[ind].close);
         }  
         if (val == "UPPER("+s+")")
         {
            Rates *rates = Rates::GetRates(symbol,Tf);
            return (rates.arr[ind].high - MathMax(rates.arr[ind].open, rates.arr[ind].close));
         }   
         if (val == "LOWER("+s+")")
         {
            Rates *rates = Rates::GetRates(symbol,Tf);
            return (MathMin(rates.arr[ind].open, rates.arr[ind].close) - rates.arr[ind].low);
         }    
         if (val == "MIN("+s+")")
         {
            double min = 10000000;
            if (int(s) == 0) 
               min = SymbolInfoDouble(symbol, SYMBOL_LASTLOW);
            else
            {
               Rates *rates = Rates::GetRates(symbol,Tf);
               for(int i=1;i<=int(s);i++)             
                  min = MathMin(min, rates.arr[i].low);
            }
            return min;
         }            
         if (val == "MAX("+s+")")
         {
            double max = 0;
            if (int(s) == 0) 
               max = SymbolInfoDouble(symbol, SYMBOL_LASTHIGH);
            else
            {
               Rates *rates = Rates::GetRates(symbol,Tf);
               for(int i=1;i<=int(s);i++)
                  max = MathMax(max, rates.arr[i].high);
            }      
            return max;
         }
         if (val == "MINOC("+s+")")
         {
            double min = 10000000;
            Rates *rates = Rates::GetRates(symbol,Tf);
            for(int i=1;i<=int(s);i++)
               min = MathMin(MathMin(min, rates.arr[i].open),rates.arr[i].close);
            return min;
         }   
         if (val == "MAXOC("+s+")")
         {
            double max = 0;
            Rates *rates = Rates::GetRates(symbol,Tf);
            for(int i=1;i<=int(s);i++)
               max = MathMax(MathMax(max, rates.arr[i].open),rates.arr[i].close);
            return max;
         }
         if (val == "FLAT("+s+")")
         {
            double min = 1000000;
            double max = 0;
            
            Rates *rates = Rates::GetRates(symbol,Tf);
            for(int i=1;i<=int(s);i++)  
            {           
               min = MathMin(min, rates.arr[i].low);
               max = MathMax(max, rates.arr[i].high);
            }    
            return max - min;
         }
         if (val == "FLATOC("+s+")")
         {
            double min = 1000000;
            double max = 0;
            Rates *rates = Rates::GetRates(symbol,Tf);
            for(int i=1;i<=int(s);i++)
            {
               min = MathMin(MathMin(min, rates.arr[i].open),rates.arr[i].close);
               max = MathMax(MathMax(max, rates.arr[i].open),rates.arr[i].close);
            }
            return max - min;
         }           
         if (val == "SMA("+s+")")
         {
            Rates *rates = Rates::GetRates(symbol,Tf,"SMA", param);
            return rates.ind[ind];
         }
         if (val == "EMA("+s+")")
         {
            Rates *rates = Rates::GetRates(symbol,Tf,"EMA", param);
            return rates.ind[ind];
         }
         if (val == "RSI("+s+")")
         {
            Rates *rates = Rates::GetRates(symbol,Tf,"RSI", param);
            return rates.ind[ind];
         }
         if (val == "ATR("+s+")")
         {
            Rates *rates = Rates::GetRates(symbol,Tf,"ATR", param);
            return rates.ind[ind];
         }
         if (val == "HL("+s+")")
         {
            Rates *rates = Rates::GetRates(symbol,Tf);
            return (rates.arr[ind].high + rates.arr[ind].low)/2; 
         }
         if (val == "HLC("+s+")")
         {
            Rates *rates = Rates::GetRates(symbol,Tf);
            return (rates.arr[ind].high + rates.arr[ind].low + rates.arr[ind].close)/3; 
         }
         if (val == "HLCC("+s+")")
         {
            Rates *rates = Rates::GetRates(symbol,Tf);
            return (rates.arr[ind].high + rates.arr[ind].low + rates.arr[ind].close + rates.arr[ind].close)/4; 
         }
         if (val == "MID("+s+")")
         {
            Rates *rates = Rates::GetRates(symbol,Tf);
            return (rates.arr[ind].open + rates.arr[ind].close)/2; 
         }     
         if (val == "SUP("+s+")")
         {
            double min = 1000000;
            double sup, last;
            sup = 0;
            
            int size = ArraySize(Rates::levels);
            MqlTick tick;
            if (SymbolInfoTick(symbol, tick))
               last = tick.last;  
            else last = 0;   
                         
            for(int i=0;i<=size-1;i++)
               if(Rates::levels[i].is_support)
               {
                  if(Rates::levels[i].is_trend)
                  {
                     double v = ObjectGetValueByTime(0, Rates::levels[i].name, tick.time, 0);
                     if (MathAbs(v - last) < min)
                     {
                        sup = v;
                        min = MathAbs(Rates::levels[i].value - last);
                     }    
                  }
                  else  
                     if (MathAbs(Rates::levels[i].value - last) < min)
                     {
                        sup = Rates::levels[i].value;
                        min = MathAbs(Rates::levels[i].value - last);
                     }    
               }
            return sup;                 
         }              
         if (val == "RES("+s+")")
         {
            double min = 1000000;
            double res, last;
            res = 0;
            
            int size = ArraySize(Rates::levels);
            MqlTick tick;
            if (SymbolInfoTick(symbol, tick))
               last = tick.last;  
            else last = 0;   
                         
            for(int i=0;i<=size-1;i++)
               if(!Rates::levels[i].is_support)
               {
                  if(Rates::levels[i].is_trend)
                  {
                     double v = ObjectGetValueByTime(0, Rates::levels[i].name, tick.time, 0);
                     if (MathAbs(v - last) < min)
                     {
                        res = v;
                        min = MathAbs(Rates::levels[i].value - last);
                     }    
                  }
                  else  
                     if (MathAbs(Rates::levels[i].value - last) < min)
                     {
                        res = Rates::levels[i].value;
                        min = MathAbs(Rates::levels[i].value - last);
                     } 
                }        
            return res;                 
         }              
      }
   } 
   
   MqlTick tick;
   if (val == "BID")
   {
      if (SymbolInfoTick(symbol, tick))
         return tick.bid;
      else
         error_calc = true;    
   }  
   if (val == "ASK")
   {
      if (SymbolInfoTick(symbol, tick))
         return tick.ask;
      else
         error_calc = true;    
   }  
   if (val == "LAST")
   {
      if (SymbolInfoTick(symbol, tick))
         return tick.last;
      else
         error_calc = true;    
   }  
   if (val == "VOL")
   {
      if (SymbolInfoTick(symbol, tick))
         return (double)tick.volume;
      else
         error_calc = true;    
   }   

   if (val == "EXPIRE")
      return round((SymbolInfoInteger(symbol, SYMBOL_EXPIRATION_TIME)- TimeCurrent() + 1)/24/60/60);  

   if (val == "TIME")
   {
      MqlDateTime str;
      TimeToStruct(TimeLocal(), str);
      return (str.hour * 60 + str.min);   
   } 

   if (val == "DAY")
   {
      MqlDateTime str;
      TimeToStruct(TimeLocal(), str);
      return(str.day_of_week);   
   } 

   if (val == "PROFIT")
   {
      if (PositionSelect(symbol))
         return PositionGetDouble(POSITION_PROFIT);  
      else
         error_calc = true; 
   }   
         
   if (val == "PRICE")
   {
      double saved_value = Value::ReadValue(symbol, val);
      if (saved_value != NULL)
         return saved_value;
      else
         if (SymbolInfoTick(symbol, tick))
            return tick.last;
         else
            error_calc = true;     
   }
   
   if (val == "TAKE" || val == "STOP" || val == "OPEN_PRICE" || val == "OPEN_VOL" || val == "RISK")
   {
      double saved_value = Value::ReadValue(symbol, val);
      return saved_value;   
   }    
           
   double d = StringToDouble(val);
   
   if ((val != "0")&&(d == 0))
   {
      debug("Ошибка в выражении: " + val);
      error_calc = true;
   }    
   
   return d;
}

//вычислить значение
double Value::Calc()  
{
   char oper;
   int operator_pos = StringFind(Str,"*"); 
   if (operator_pos >= 0)
      oper = '*';
   else   
   {
      operator_pos = StringFind(Str,"+");
      if (operator_pos >= 0)
         oper = '+';
      else
      {
         operator_pos = StringFind(Str,"-");
         if (operator_pos >= 0)
            oper = '-';
         else   
         {
            operator_pos = StringFind(Str,"/");
            if (operator_pos >= 0)
               oper = '/'; 
         }
      }
   }     

   CSymbolInfo si;
   si.Name(symbol);
   
   if (operator_pos > 0)
   {
      double val1 = CalcPart(StringSubstr(Str, 0, operator_pos));
      double val2 = CalcPart(StringSubstr(Str, operator_pos + 1));
      
      switch(oper)
      {
         case '*' : return(si.NormalizePrice(val1*val2));  break;
         case '+' : return(si.NormalizePrice(val1+val2));  break;
         case '-' : return(si.NormalizePrice(val1-val2));  break;
         case '/' : return(si.NormalizePrice(val1/val2));  break;
         default: return 0; error_calc = true; break;
      }
      
   } 
   else 
      return si.NormalizePrice(CalcPart(Str));
}

//проверка части значения
bool Value::CheckPart(string val)
{
   int pos1, pos2, pos3, ind, param = 0;
   string v = val;
   
   pos1 = StringFind(val,"(");
   if (pos1 >= 0)
   {
      pos2 = StringFind(val,")");
      
      if((pos2 >= 0)&&(pos2 > pos1))
      {
         string s = StringSubstr(val, pos1 + 1, pos2 - pos1 - 1);
         pos3 = StringFind(s,",");
         if (pos3 >= 0)
         {
            ind = (int)StringToInteger(StringSubstr(s, 0, pos3));
            param = (int)StringToInteger(StringSubstr(s, pos3 + 1));
            if ((StringSubstr(s, pos3 + 1) != "0")&&(param == 0))
            {
               debug("Не определен параметр в выражении: " + val);
               return false;
            }  
         }
         else ind = (int)StringToInteger(s);
 
         if ((StringSubstr(s, 0, pos3) != "0")&&(ind == 0))
         {
            debug("Не определен индекс бара в выражении: " + val);
            return false;
         } 
         
         StringReplace(val, "("+s+")", "(0)");   
         StringReplace(val, "OPEN(0)", "0");    
         StringReplace(val, "CLOSE(0)", "0");  
         StringReplace(val, "HIGH(0)", "0");  
         StringReplace(val, "LOW(0)", "0");  
         StringReplace(val, "VOLUME(0)", "0");  
         StringReplace(val, "BODY(0)", "0");   
         StringReplace(val, "UPPER(0)", "0");   
         StringReplace(val, "LOWER(0)", "0");  
         StringReplace(val, "MID(0)", "0");
         StringReplace(val, "HL(0)", "0");        
         StringReplace(val, "HLC(0)", "0");  
         StringReplace(val, "HLCC(0)", "0");  
         StringReplace(val, "MIN(0)", "0");
         StringReplace(val, "MAX(0)", "0"); 
         StringReplace(val, "MINOC(0)", "0");
         StringReplace(val, "MAXOC(0)", "0"); 
         StringReplace(val, "SMA(0)", "0");
         StringReplace(val, "EMA(0)", "0");
         StringReplace(val, "RSI(0)", "0");
         StringReplace(val, "ATR(0)", "0");
         StringReplace(val, "SUP(0)", "0");  
         StringReplace(val, "RES(0)", "0");
         StringReplace(val, "FLAT(0)", "0");  
         StringReplace(val, "FLATOC(0)", "0");       
      }
      else
      {
         debug("Не найдена закрывающаяся скобка в выражении: " + val);
         return false;         
      }

   } 
   
   StringReplace(val, "BID", "0");
   StringReplace(val, "ASK", "0"); 
   StringReplace(val, "LAST", "0"); 
   StringReplace(val, "VOL", "0"); 
   StringReplace(val, "PRICE", "0");
   StringReplace(val, "OPEN_PRICE", "0");
   StringReplace(val, "OPEN_VOL", "0");
   StringReplace(val, "STOP", "0");
   StringReplace(val, "TAKE", "0");
   StringReplace(val, "RISK", "0");   
   StringReplace(val, "DAY", "0");  
   StringReplace(val, "TIME", "0");  
   StringReplace(val, "PROFIT", "0");  
   StringReplace(val, "EXPIRE", "0");  
    
   double d = StringToDouble(val);
   
   if ((val != "0")&&(d == 0))
   {
      debug("Ошибка в выражении: " + v);
      return false;
   }    
   
   return true;
}

// проверить значение 
static bool Value::Check()
{
   if (!GetTf())
      return false;
      
   int operator_pos = StringFind(Str,"*"); 
   if (operator_pos == -1)
   {
      operator_pos = StringFind(Str,"+");
      if (operator_pos == -1)
      {
         operator_pos = StringFind(Str,"-");
         if (operator_pos == -1)
            operator_pos = StringFind(Str,"/");
      };
   };
   
   if (operator_pos > 0)
   {
      if (!CheckPart(StringSubstr(Str, 0, operator_pos)))
         return false;
      
      if (!CheckPart(StringSubstr(Str, operator_pos + 1)))
         return false;
   } 
   else 
      if (!CheckPart(Str))
         return false;
   
   return true;
}



//+------------------------------------------------------------------+
//| Класс для описания условия                                       |
//+------------------------------------------------------------------+

class Condition
{
private:
                    string operation; //операция сравнения
                    string symbol;                      
public:
                    Value *part1;   //часть 1
                    Value *part2;   //часть 2
                    Condition(string val, string symb);   //конструктор
                    ~Condition();  //деструктор
                    string Str;    //строка условия
                    bool Parse(); //симантический разбор
                    bool Calc();  //вычислить условие для символа                
};

//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
Condition::Condition(string val, string symb)
{
   Str = val;
   symbol = symb;
}

//+------------------------------------------------------------------+
//| Деструктор                                                       |
//+------------------------------------------------------------------+
Condition::~Condition()
{
   delete part1;
   delete part2;
}


//+------------------------------------------------------------------+
//| Cимантический разбор                                             |
//+------------------------------------------------------------------+
bool Condition::Parse()
{
   int operator_pos;
  // string substr;
   
   debug("Разбираем условие: " + Str);

   if(Str == "OR")
     return true;
        
   operator_pos = StringFind(Str,">=");
   if (operator_pos == -1)
   {
      operator_pos = StringFind(Str,"<=");
      if (operator_pos == -1)
      {
         operator_pos = StringFind(Str,"!=");
         if (operator_pos == -1)
         {
            operator_pos = StringFind(Str,">");
            if (operator_pos == -1)
            {
               operator_pos = StringFind(Str,"<");
               if (operator_pos == -1)
               {
                  operator_pos = StringFind(Str,"=");
                  if (operator_pos == -1)
                  {
                     debug("Не найден оператор сравнения в условии");
                     return false;
                  } else operation = "=";
               } else operation = "<";
            } else operation = ">";
         } else operation = "!=";
      } else operation = "<=";
   } else operation = ">=";
   
   if ((operator_pos == 0)||((operator_pos + StringLen(operation))==StringLen(Str)))
   {
      debug("Неверно задано условиие");
      return false;      
   }
   
   part1 = new Value(StringSubstr(Str, 0, operator_pos), symbol);
   part2 = new Value(StringSubstr(Str, operator_pos + StringLen(operation)), symbol);   
   
   if (!part1.Check())
      return false;   
   
   if (!part2.Check())
      return false;
         
   return true;
}

//+------------------------------------------------------------------+
//| Вычислить условие                                                |
//+------------------------------------------------------------------+
bool Condition::Calc()
{ 
   if(Str == "OR")
     return NULL;
     
   //debug("Вычисляем условие: " + Str + " для символа: " + symbol);
   
   double p1 = part1.Calc();
   double p2 = part2.Calc();
   //debug("p1 = " + DoubleToString(p1,2));
   //debug("p2 = " + DoubleToString(p2,2));
      
   if (part1.error_calc || part2.error_calc)
   {
      Print("Ошибка вычисления условия: " + Str + " для символа: " + symbol);
      return false;
   }

   CSymbolInfo si;
   si.Name(symbol);
   
   if(operation == "=")
      if (si.NormalizePrice(p1-p2)==0)
         return true;

   if(operation == "<")
      if (p1 < p2)
         return true;

   if(operation == ">")
      if (p1 > p2)
         return true;

   if(operation == "<=")
      if (p1 <= p2)
         return true;

   if(operation == ">=")
      if (p1 >= p2)
         return true;
         
    if(operation == "!=")
      if (si.NormalizePrice(p1-p2) != 0)
         return true;
              
   return false;
}
 
//+------------------------------------------------------------------+
