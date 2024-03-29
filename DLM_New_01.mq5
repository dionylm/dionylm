//+------------------------------------------------------------------+
//|                                                          DLM.mq5 |
//|                                        Copyright 2021, Diony LM. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, Diony LM. Licensa 2022"
#property link      "https://www.mql5.com"
#property version   "15.50"
#property description "Projeto iniciado em março de 2021"
/*
#property description "2.0  Cruzamento de médias"
#property description "3.0  Gift, IFR e Stoploss"
#property description "4.0  Stop ATR e Preço Médio"
#property description "5.0  Mercado lateral e controle de horário"
#property description "6.0  AI ajustado para B3 e Forex"
#property description "7.0  Saldo diário de Gain e Loss"
#property description "8.0  Price Action"
#property description "9.0  Stop nas médias"
#property description "10.0 Melhorias nas funções de negociação"
#property description "11.0 Stoploss especial por entrada"
#property description "12.0 Redução de metas por tempo"
#property description "13.0 Estratégia de Topos e Fundos"
#property description "14.0 Trailing progressivo"
*/
#property description "15.0  Melhorias de fluxo"
#property description "15.10 Cruzamento rápido de médias"
#property description "15.11 Restrição contra tendência e Verificação de candle para Alinhamento"
// 15.5 Reorganização de funções
// 15.51 Estética menu
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
CTrade         d_trade;
CSymbolInfo    d_symbol;

enum Tamanho_PM
  {
   Nenhum = 0, //Não fazer
   Ajuste = 1, //Só ajusta
   x2 = 2,     //2 x lote
   x3 = 3,     //3 x lote
   x4 = 4,     //4 x lote
   x5 = 5,     //5 x lote
  };
enum AjusteStop
  {
   NA = 0,  //Não ajusta
   PR = 1,  //Desde o primeiro
   DO = 2,  //Após dobrar
   MA = 3,  //No Máximo de lotes
   AM = 4,  //Após o máximo
  };
enum OpcoesStop
  {
   Padrao = 0,  //Padrão definido
   ATR1 = 1,    //Um ATR
   Espec = 2,   //Esp. da Estratégia
  };
enum StopLoss
  {
   SATR = 0,   //Stop por ATR
   SFixo = 1,  //Stop com valor fixo
   SCandle = 2,//Stop no candle anterior
   SMR = 3,    //Stop na média rápida
   SML = 4,    //Stop na média lenta
  };
enum TrailStop
  {
   TC = 0,  //Stop no candle anterior
   TF = 1,  //Stop com valor fixo
   TR = 2,  //Stop na média rápida
   TL = 3,  //Stop na média lenta
   TP = 4,  //Trailing Progressivo
  };
enum ValorStop
  {
   Atual = 0,     //Candle atual
   Anterior = 1,  //Candle anterior
   Dois = 2,      //2 Candles antes
   Tres = 3,      //3 Candles antes
  };
enum ValorTStop
  {
   Atual = 0,     //Candle atual
   Anterior = 1,  //Candle anterior
   Dois = 2,      //2 Candles antes
   Tres = 3,      //3 Candles antes
  };
enum DebugMode
  {
   n = 0,   //0 Debug desativado
   a = 1,   //1 Informações gerais
   b = 2,   //2 Informações das ordens
   c = 3,   //3 Cálculos / Filtros
   d = 4,   //4 Funções / BE / TS
   e = 5,   //5 Detalhamento máximo
  };

//+------------------------------------------------------------------+
//| Variáveis Input                                                  |
//+------------------------------------------------------------------+
input group "# CONFIGURAÇÕES DE EXECUÇÃO DE ORDENS #"
input ENUM_ORDER_TYPE_FILLING preenchimento  = ORDER_FILLING_RETURN; //Preenchimento da ordem
input ulong                magicNum          = 777777; //Magic number
input ulong                desvPts           = 1000; //Desvio em pontos
input double               lote              = 1; //Tamanho do lote

input group "### - - - ESTRATÉGIAS DE ENTRADA - - - ###"
input bool                 tradetende        = false; //Entrada por Tendência
input bool                 price_action      = true; //Entrada por Price Action
input bool                 mm_cross          = true; //Entrada por Cruzamento de Médias
input bool                 gift              = true; //Entrada por Gift
input bool                 ifr_cross         = true; //Entrada por IFR
input bool                 alinhax2          = true; //Dobra o lote em alinhamento
input bool                 vendido           = true; //Operar vendido?

input group "### - PREÇO MÉDIO E MERCADO LATERAL - ###"
input Tamanho_PM           precoMedio        = 3; //Fazer preço médio? (Máximo)
input double               limiteMedio       = 10; //Prejuízo mínimo para médio (R$ / lote)
input bool                 lotemedio         = true; //Usar lote mínimo para médio?
input AjusteStop           ajusteStopPM      = 1; //Ajustar Stop Loss ao fazer médio?
input bool                 lateraltrade      = false; //Negocia mercado lateral
input double               rangeLateral      = 50; //Amplitude do filtro de lateralidade
input bool                 medioLateral      = false; //Fazer médio em lateralidade?

input group "###  - - STOP LOSS E TAKE PROFIT - -  ###"
input StopLoss             TipoStop          = 0; //Tipo de Stop Loss padrão
input OpcoesStop           Esp_Stop          = 2; //Stop Loss dif. por entrada?
input ValorStop            nivelStop         = 3; //Nível do Stop Loss em candles
input double               stopLossMin       = 100; //Stop Loss mínimo
input double               stopLossMax       = 900; //Stop Loss máximo
input int                  takeProfit        = 3; //Take Profit (multiplicador)

input group "### - - BREAK EVEN E TRAILING STOP - - ###"
input double               gatilhoBE         = 75; //Gatilho Break Even
input double               ajusteBE          = 25; //Ajuste do Break Even
input double               gatilhoTS         = 100; //Gatilho Trailing Stop
input double               stepTS            = 75; //Step Trailing Stop
input TrailStop            TipoTrail         = 0; //Tipo de Trailing Stop
input ValorTStop           nivelTStop        = 3; //Nível Trailing Stop em candles

input group "### - - - - - MÉDIAS MÓVEIS - - - - - ###"
input ENUM_TIMEFRAMES      mm_tempo_grafico  = PERIOD_CURRENT; //Tempo gráfico das médias
input ENUM_APPLIED_PRICE   ma_preco          = PRICE_CLOSE; //Preço para cálculo das médias
input int                  ma_periodo        = 20; //Período da média principal
input int                  ma_desloc         = 0; //Deslocamento da média principal
input ENUM_MA_METHOD       ma_metodo         = MODE_SMA; //Método da média móvel principal
input int                  mm_rapida_periodo = 9; //Periodo média rápida
input ENUM_MA_METHOD       mm_metodo_rapida  = MODE_EMA; //Método média rápida
input int                  mm_lenta_periodo  = 20; //Periodo média lenta
input ENUM_MA_METHOD       mm_metodo_lenta   = MODE_SMA; //Método média lenta

input group "### - - - - - - - - ATR - - - - - - - - ###"
input ENUM_TIMEFRAMES      atr_tempo_grafico = PERIOD_CURRENT; //Tempo gráfico do ATR
input double               constATR          = 3; //Const.ATR p/ TS (Ref. 2.7 a 3.4)
input int                  atr_periodo       = 10; //Período do ATR

input group "### - - - - - - - - IFR - - - - - - - - ###"
input ENUM_TIMEFRAMES   ifr_tempo_grafico    = PERIOD_CURRENT; //Tempo gráfico do IFR
input int               ifr_periodo          = 5; //Período IFR
input int               ifr_sobrecompra      = 90; //Nível de sobrecompra IFR(70)
input int               ifr_sobrevenda       = 10; //Nível de sobrevenda IFR(30)

input group "###  - - - - - PABABOLIC SAR - - - - -  ###"
input double             Signal_SAR_Step     = 0.02; // Parabolic SAR Speed increment(0.02)
input double             Signal_SAR_Maximum  = 0.2; // Parabolic SAR Maximum rate(0.2)

input group "###  - - CONFIGURAÇÕES DE FILTROS - -  ###"
input bool              filtro_tende         = true; //Filtro de tendência?
input bool              filtro_3m            = true; //Filtro anti mudança de tendência?
input bool              filtro_TouF          = true; //Filtro de Topos e Fundos?
input bool              filtroSentTF         = true; //Entrada no sentido de Topos e Fundos
input bool              filtro_ifr           = true; //Filtro de IFR?

input group "###  - - - - - - CANDLES - - - - - -  ###"
input double            vela_minima          = 50; //Tamanho mínimo de candle p/ ordens
input int               prop                 = 75; //Máximo de pavio(%) / 0 = desliga
input int               pavio                = 25; //Pullback máximo(%) / 0 = desliga

input group "### - - - - - - HORÁRIOS - - - - - - ###"
input string            inicio_operacoes     = "09:00"; //Horário de início das negociações
input string            hora_limite_abre_op  = "17:00"; //Horário limite para abrir posição
input string            hora_limite_fecha_op = "17:30"; //Horário limite para fechar posição
input bool              daytrade             = true; //Zerar operações no fim do dia?
input bool              tradehorarestrita    = false; //Negocia nos horários retritos?
input string            inicio_itervalo_1    = "09:55"; //Restrição 1 (início)
input string            fim_intervalo_1      = "10:10"; //Restrição 1 (fim)
input string            inicio_itervalo_2    = "10:20"; //Restrição 2 (início)
input string            fim_intervalo_2      = "10:35"; //Restrição 2 (fim)

input group "### - - - - - - - METAS - - - - - - - ###"
input double            valorMaximoGanho     = 500; //Meta financeira (R$) / 0 = desliga
input double            valorMaximoPerda     = 200; //Limite de perda (R$) / 0 = desliga
input bool              mostraResultado      = true; //Exibe resultado?
input bool              saiGanhando          = true; //Reduz a meta para sair no lucro?

input group "### - - - - - - DEBUG MODE - - - - - - ###"
input DebugMode         debug                = 3; //Nível de debug
input bool              mostraOHLC           = true; //Exibe OHLC?
input bool              exibe_ind            = false; //Adiciona Indicadores no gráfico?

//+------------------------------------------------------------------+
//|  Variáveis para os indicadores e filtros                         |
//+------------------------------------------------------------------+
int      ifr_Handle;          // Handle controlador para o IFR
double   ifr_Buffer[];        // Buffer para armazenamento dos dados do IFR
int      atr_Handle;          // Handle controlador para o ATR
double   atr_Buffer[];        // Buffer para armazenamento dos dados do ATR
int      sar_Handle;
double   sar_Buffer[];
int      mm_rapida_Handle;    // Handle controlador da média móvel rápida
double   mm_rapida_Buffer[];  // Buffer para armazenamento dos dados das médias
int      mm_lenta_Handle;     // Handle controlador da média móvel lenta
double   mm_lenta_Buffer[];   // Buffer para armazenamento dos dados das médias
int      mm_principal_Handle; // Handle da média móvel
double   mm_principal_Buffer[];//Array da média móvel de tendencia
//--- Definição de Variáveis de negociação
MqlTick  tick;
MqlRates rates[];
int aName = d_symbol.Name(_Symbol);//Nome do simbolo para verificação de ordens abertas
double ticSize = d_symbol.TickSize();//Tamanho do tic
double lotemin = d_symbol.ContractSize();//Tamanho do lote mínimo
//double   PRC;                 //Preço normalizado
//double   STL;                 //StopLoss normalizado
//double   TKP;                 //TakeProfit normalizado
double   d_profit;            //Usada na função de Preço Médio e ontick
int tendencia;
bool     posAberta      = true;
bool     ordPendente    = true;
//bool     filtro_lateral = false; //Filtro para lateralidade
bool     beAtivo        = false; //Break Even e Trailing Stop
string   ordemComment;           //Comentário das ordens
// Variáveis da função de detecção de topos e fundos
string UltimoTopo;
string UltimoFundo;
bool TouF = false; //Último foi Topo?
bool FiltroTouF = false;
int tende_touf;
double Topo1 = 0;
double Topo2 = 0;
double Topo3 = 0;
double Fundo1 = 0;
double Fundo2 = 0;
double Fundo3 = 0;
// Variáveis da verificação de lincença
bool licenca = true;
string agoraL, limiteL;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Verificação de período de testes
   agoraL = TimeToString(datetime(TimeCurrent()), TIME_DATE);
   limiteL = TimeToString(datetime("2023/12/31"), TIME_DATE);
   if(agoraL > limiteL)
      licenca = false;
//--- Médias e IFR
   mm_principal_Handle  = iMA(_Symbol, mm_tempo_grafico, ma_periodo, ma_desloc, ma_metodo, ma_preco);
   mm_rapida_Handle     = iMA(_Symbol,mm_tempo_grafico,mm_rapida_periodo,0,mm_metodo_rapida,ma_preco);
   mm_lenta_Handle      = iMA(_Symbol,mm_tempo_grafico,mm_lenta_periodo,0,mm_metodo_lenta,ma_preco);
   ifr_Handle           = iRSI(_Symbol,ifr_tempo_grafico,ifr_periodo,ma_preco);
   atr_Handle           = iATR(_Symbol,atr_tempo_grafico,atr_periodo);
   sar_Handle           = iSAR(_Symbol,mm_tempo_grafico,Signal_SAR_Step,Signal_SAR_Maximum);
   if(mm_principal_Handle==INVALID_HANDLE || mm_rapida_Handle==INVALID_HANDLE || mm_lenta_Handle==INVALID_HANDLE || ifr_Handle==INVALID_HANDLE || atr_Handle==INVALID_HANDLE || sar_Handle==INVALID_HANDLE)
     {
      Alert("Erro ao tentar criar Handles para os indicadores - erro: ",GetLastError(),"!");
      return(INIT_FAILED);
     }
   if(debug>0)
      Print("--> Symbol Name: ", d_symbol.Name(), " / Tick Size: ", d_symbol.TickSize(), " / Lote min.: ", d_symbol.ContractSize(), " / Lote prog.: ", lote," / Meta de lucro: R$", DoubleToString(valorMaximoGanho,2), " / Limite de perda: R$", DoubleToString(valorMaximoPerda,2));
   if(debug>1)
      Print("--> Entradas: Tendência: ",tradetende," / Price Action: ",price_action," / Cruzamento de Médias: ",mm_cross," / Gift: ",gift," / IFR: ",ifr_cross);
   if(debug>2)
      Print("--> Break Even: ",gatilhoBE," / Ajuste BE: ",ajusteBE," / Trailing Stop: ",gatilhoTS," / Step TS: ",stepTS," / Horário limite para abrir posição: ", hora_limite_abre_op);
   if(debug>3)
      Print("--> Data atual: ", agoraL, " / Limite de uso: ", limiteL, " / Licença válida? ", licenca);
// Definições dos atributos ordens
   d_trade.SetTypeFilling(preenchimento);
   d_trade.SetDeviationInPoints(desvPts);
   d_trade.SetExpertMagicNumber(magicNum);
// Organiza os arrays
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(mm_principal_Buffer, true);
   ArraySetAsSeries(mm_rapida_Buffer, true);
   ArraySetAsSeries(mm_lenta_Buffer, true);
   ArraySetAsSeries(sar_Buffer, true);
// Para adicionar no gráfico os indicadores:
   if(exibe_ind)
     {
      ChartIndicatorAdd(0,0,mm_rapida_Handle);
      ChartIndicatorAdd(0,0,mm_lenta_Handle);
      ChartIndicatorAdd(0,0,mm_principal_Handle);
      ChartIndicatorAdd(0,1,ifr_Handle);
      ChartIndicatorAdd(0,1,atr_Handle);
      ChartIndicatorAdd(0,0,sar_Handle);
     }
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(mm_rapida_Handle);
   IndicatorRelease(mm_lenta_Handle);
   IndicatorRelease(mm_principal_Handle);
   IndicatorRelease(ifr_Handle);
   IndicatorRelease(atr_Handle);
   IndicatorRelease(sar_Handle);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(!SymbolInfoTick(Symbol(),tick))
     {
      Alert("Erro ao obter informações de Preços: ", GetLastError());
      return;
     }
   if(CopyRates(_Symbol, mm_tempo_grafico, 0, 6, rates)<0)
     {
      Alert("Erro ao obter as informações de MqlRates: ", GetLastError());
      return;
     }
   if(CopyBuffer(mm_principal_Handle, 0, 0, 6, mm_principal_Buffer)<0)
     {
      Alert("Erro ao copiar dados da média móvel: ", GetLastError());
      return;
     }
// Chama função para verificar nova vela
   bool temosNovaVela = TemosNovaVela(); //Retorna true se tivermos uma nova vela
   if(temosNovaVela && debug>4)
      Print("Nova vela detectada!");
// Condições de Negociação: Verifica ordens abertas e pendentes e chama Breakeven e Trailing Stop
// Verifica se tem ordem pendente
   if(OrdersTotal() == 0)
     {
      ordPendente = false;
      if(debug>4 && temosNovaVela)
         Print("Ordem pendente definida FALSE! Nenhuma ordem!");
     }
   else
     {
      for(int i = OrdersTotal()-1; i>=0; i--)
        {
         ulong ticket = OrderGetTicket(i);
         string symbol = OrderGetString(ORDER_SYMBOL);
         ulong magic = OrderGetInteger(ORDER_MAGIC);
         if(symbol == _Symbol && magic == magicNum)
           {
            ordPendente = true;
            if(debug>4 && temosNovaVela)
               Print("Ordem pendente definida TRUE!");
            break;
           }
         else
           {
            ordPendente = false;
            if(debug>4 && temosNovaVela)
               Print("Ordem pendente definida FALSE! Não encontrada ordem do ativo!");
           }
        }
     }
// Verifica se tem posição aberta
   if(PositionsTotal() == 0)
     {
      posAberta = false;
      if(debug>4 && temosNovaVela)
         Print("Posição aberta definida FALSE! Nenhuma posição!");
     }
   else
     {
      for(int i = PositionsTotal()-1; i>=0; i--)
        {
         string symbol = PositionGetSymbol(i);
         if(d_symbol.Name() == symbol)
           {
            posAberta = true;
            d_profit = PositionGetDouble(POSITION_PROFIT);
            if(debug>4 && temosNovaVela)
               Print("Posição aberta definida TRUE!");
            break;
           }
         if(d_symbol.Name() != symbol)
           {
            posAberta = false;
            if(debug>4 && temosNovaVela)
               Print("Posição aberta definida FALSE! Não encontrada posição do ativo!");
           }
        }
     }
   if(!posAberta)
      beAtivo = false;//reset da variavel beAtivo em caso de não ter posição aberta
   if(posAberta && !beAtivo && d_profit>0)
      BreakEven(tick.ask, tick.bid, temosNovaVela);//se passa a ter posição aberta inicia o BreakEven (no BE a variavel beAtivo é setada TRUE impedindo novo chamamento do BE)
   if(posAberta && beAtivo)
      TrailingStop(tick.ask, tick.bid, temosNovaVela);//se tem posição aberta e já foi acionado o BE, passa a monitorar o TrailingStop

//+------------------------------------------------------------------+
//|-- Tarefas a serem executadas apenas na abertura de novas velas --|
//+------------------------------------------------------------------+
   if(temosNovaVela) // Toda vez que existir uma nova vela entrar nesse 'if'
     {
      if(debug>3)
         Print("Início do script chamado a cada nova vela!");
      // Copiar um vetor de dados tamanho cinco para o vetor mm_Buffer
      CopyBuffer(mm_rapida_Handle,0,0,10,mm_rapida_Buffer);
      CopyBuffer(mm_lenta_Handle,0,0,10,mm_lenta_Buffer);
      CopyBuffer(ifr_Handle,0,0,4,ifr_Buffer);
      CopyBuffer(atr_Handle,0,0,4,atr_Buffer);
      // Ordenar o vetor de dados:
      ArraySetAsSeries(mm_rapida_Buffer,true);
      ArraySetAsSeries(mm_lenta_Buffer,true);
      ArraySetAsSeries(ifr_Buffer,true);
      ArraySetAsSeries(atr_Buffer,true);
      //+------------------------------------------------------------------+
      //|             FILTROS E LOGICAS DE COMPRA E VENDA                  |
      //+------------------------------------------------------------------+
      tendencia = Tendencia();
      // FILTRO de TOPOS e FUNDOS
      if(filtro_TouF || filtroSentTF) // Verifica se é necessário chamar a função de Topos e Fundos
         tende_touf = ToposeFundos();
      // Verifica horário de negociação e metas programadas
      bool timetotrade = TimetoTrade();
      bool metaDiaria = metaOuPerda();
      // FILTRO de COMPRA ou VENDA por IFR
      bool filtroIFR = (ifr_Buffer[1] < ifr_sobrecompra && rates[1].open<rates[1].close) || (ifr_Buffer[1] > ifr_sobrevenda && rates[1].open>rates[1].close) || !filtro_ifr;
      // FILTRO DE PAVIO PARA COMPRA ou VENDA
      bool pavioBom = (((rates[1].high-rates[1].close)*100/(rates[1].high - rates[1].low))<pavio && rates[1].open<rates[1].close) ||
                      (((rates[1].close-rates[1].low)*100/(rates[1].high - rates[1].low))<pavio && rates[1].open>rates[1].close) || pavio == 0; // Proporção do pavio superior x total < definido
      // FILTRO DE PROPORÇÃO PARA COMPRA ou VENDA
      bool propBoa = (((((rates[1].high - rates[1].low)-(rates[1].close - rates[1].open))*100/(rates[1].high - rates[1].low))<prop || prop == 0) && // Proporção dos pavios x total > definido
                      vela_minima < rates[1].high - rates[1].low && vela_minima*0.5 < rates[1].close - rates[1].open && rates[1].open<rates[1].close) ||
                     (((((rates[1].high - rates[1].low)-(rates[1].open - rates[1].close))*100/(rates[1].high - rates[1].low))<prop || prop == 0) && // Proporção dos pavios x total
                      vela_minima < rates[1].high - rates[1].low && vela_minima*0.5 < rates[1].open - rates[1].close && rates[1].open>rates[1].close);
      // FILTRO DE MÉDIAS MÓVEIS (Evita negociações próximo a possíveis mudanças na direção do mercado)
      bool filtro_mMm = (mm_lenta_Buffer[1] < mm_rapida_Buffer[1] && mm_rapida_Buffer[1] < mm_principal_Buffer[1]) ||
                        (mm_lenta_Buffer[1] > mm_rapida_Buffer[1] && mm_rapida_Buffer[1] > mm_principal_Buffer[1]); //Média rápida entre a principal e a lenta
      if(mostraOHLC)
         Print("OHLC: Open ",rates[1].open, "  / High ", rates[1].high, "  / Low ", rates[1].low, "  / Close ", rates[1].close, " / ATR ", DoubleToString(atr_Buffer[1],1), " / IFR ", DoubleToString(ifr_Buffer[1],1));
      if(debug>3)
        {
         Print("Filtros (false) => Financeiro: ", metaDiaria, " / Tendência do Mercado: ", tendencia, " / Médias: ", filtro_mMm);
         Print("Filtros (true)  => Horário: ", timetotrade, " / IFR: ", filtroIFR, " / Pavio: ", pavioBom, " / Proporção: ", propBoa);
        }
      //+------------------------------------------------------------------+
      //|--     Início dos cálculos e script propriamente dito           --|
      //+------------------------------------------------------------------+
      // Verifica horário de negociação programado e fecha operações abertas uma a uma (evita erro de posição menor que lote)
      if(TimeToString(TimeCurrent(),TIME_MINUTES)>hora_limite_fecha_op && PositionGetString(POSITION_SYMBOL) == d_symbol.Name() && PositionsTotal()>0 && daytrade && hora_limite_fecha_op != "00:00")
        {
         Print("-----> Fim do Tempo Operacional: encerrar posições abertas!");
         string symbol = PositionGetString(POSITION_SYMBOL);
         ulong magic = PositionGetInteger(POSITION_MAGIC);
         double qtdAtual = MathAbs(PositionGetDouble(POSITION_VOLUME));
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && magic == magicNum && symbol == _Symbol)
            d_trade.Sell(qtdAtual, _Symbol, 0, 0, 0, "Fechamento de posição comprada");
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && magic == magicNum && symbol == _Symbol)
            d_trade.Buy(qtdAtual, _Symbol, 0, 0, 0, "Fechamento de posição vendida");
        }
      if(!metaDiaria && timetotrade && !ordPendente && !posAberta)
        {
         if(
            (
               (
                  (!filtro_tende ||
                   (
                      (
                         (rates[1].open>mm_principal_Buffer[1] && rates[1].close>mm_principal_Buffer[1]) || (rates[1].high-rates[1].close<(rates[1].close-rates[1].open)/2)
                      ) && rates[1].open<rates[1].close
                   ) ||
                   (
                      (
                         (rates[1].open<mm_principal_Buffer[1] && rates[1].close<mm_principal_Buffer[1]) || (rates[1].close-rates[1].low<(rates[1].open-rates[1].close)/2)
                      ) && rates[1].open>rates[1].close
                   )
                  )
               ) && tendencia != 0
            ) && (!filtroSentTF || (rates[1].open<rates[1].close && !TouF) || (rates[1].open>rates[1].close && TouF))
         ) // Verifica regras gerais de negociação e meta diária
         
           {
            if(filtro_3m && filtro_mMm && debug>2)
               Print("# Possível mudança de tendência verificada. Operações pausadas pelo filtro de médias móveis");
            if(filtro_TouF && FiltroTouF && debug>2)
               Print("# Operações pausadas pelo filtro de Topos ou Fundos");
            if(((compra_tende() && compra_pa()) || compra_gift()) && compra_mm_cross() && (pavioBom || propBoa))
              {
               ordemComment = "Alinhamento de Compra";
               CalculosCompra();
              }
            if(((vende_tende() && vende_pa()) || vende_gift()) && vende_mm_cross() && (pavioBom || propBoa))
              {
               ordemComment = "Alinhamento de Venda";
               CalculosVenda();
              }
            if(posAberta && precoMedio>0 && d_profit<limiteMedio && PositionsTotal()<lote*precoMedio)
               if((POSITION_TYPE_BUY && (compra_tende() || compra_pa() || compra_mm_cross())) || (POSITION_TYPE_SELL && (vende_pa() || vende_tende() || vende_mm_cross())))
                  Medio(temosNovaVela, pavioBom, propBoa);

            //Negociação por tendência
            if(tradetende && tendencia != 0 && tendencia != 1 && propBoa && pavioBom && (!filtro_3m || !filtro_mMm) && (!filtro_TouF || !FiltroTouF))
              {
               if(compra_tende())
                 {
                  ordemComment = "Compra Tendência";
                  if(debug>3)
                     Print("Compra Tendência");
                  CalculosCompra();
                 }
               if(vende_tende())
                 {
                  ordemComment = "Venda Tendência";
                  if(debug>3)
                     Print("Venda Tendência");
                  CalculosVenda();
                 }
              }

            //Negociação por Price Action
            if(price_action && tendencia != 0 && tendencia != 1 && propBoa && pavioBom && (!filtro_3m || !filtro_mMm) && (!filtro_TouF || !FiltroTouF))
              {
               if(compra_pa())
                 {
                  ordemComment = "Compra PA";
                  if(debug>3)
                     Print("Compra PA");
                  CalculosCompra();
                 }
               if(vende_pa())
                 {
                  ordemComment = "Venda PA";
                  if(debug>3)
                     Print("Venda PA");
                  CalculosVenda();
                 }
              }

            //Negociação por MM_cross
            if(mm_cross && tendencia != 0 && tendencia != 1 && (!filtro_3m || !filtro_mMm) && (!filtro_TouF || !FiltroTouF))
              {
               if(compra_mm_cross())
                 {
                  ordemComment = "Compra Médias";
                  if(debug>3)
                     Print("Compra Médias");
                  CalculosCompra();
                 }
               if(vende_mm_cross())
                 {
                  ordemComment = "Venda Médias";
                  if(debug>3)
                     Print("Venda Médias");
                  CalculosVenda();
                 }
              }

            // Negociação por Gift
            if(gift && tendencia != 0 && (!filtro_3m || !filtro_mMm) && (!filtro_TouF || !FiltroTouF))
              {
               if(compra_gift())
                 {
                  ordemComment = "Compra Gift";
                  if(debug>3)
                     Print("Compra Gift");
                  CalculosCompra();
                 }
               if(vende_gift())
                 {
                  ordemComment = "Venda Gift";
                  if(debug>3)
                     Print("Venda Gift");
                  CalculosVenda();
                 }
              }

            // Negociação por IFR
            if(ifr_cross && tendencia != 0 && (!filtro_3m || !filtro_mMm) && (!filtro_TouF || !FiltroTouF))
              {
               if(compra_ifr_cross())
                 {
                  ordemComment = "Compra IFR";
                  if(debug>3)
                     Print("Compra IFR");
                  CalculosCompra();
                 }
               if(vende_ifr_cross())
                 {
                  ordemComment = "Venda IFR";
                  if(debug>3)
                     Print("Venda IFR");
                  CalculosVenda();
                 }
              }
           }
         // Negociação em lateralidades
         if(lateraltrade && tendencia == 0 && !posAberta && !ordPendente)
            Lateral(pavioBom, propBoa, timetotrade);
        }

      if(precoMedio>0 && posAberta && d_profit<0) // Chama a função de preço médio
         Medio(temosNovaVela, pavioBom, propBoa);
      if(posAberta)
         StopCheck(); // Verifica se a ordem aberta possui Stop Loss
      // --- Debug de testes
      if(debug>0)
        {
         if(tendencia == 0 && debug>4)
            Print("@ Mercado Lateral!");
         if(tendencia == 1 && debug>2)
            Print("# Resistência detectada!");

         string info_tende;
         string info_ifr;
         string info_fecha;
         string info_prop;
         string info_vela;
         string info_ordem;
         if(rates[1].open < rates[1].close)
            info_vela = "POSITIVO";
         else
            info_vela = "NEGATIVO";
         if(rates[1].open > mm_principal_Buffer[1] && rates[1].close > mm_principal_Buffer[1])
            info_tende = "COMPRA ";
         else
            if(rates[1].open < mm_principal_Buffer[1] && rates[1].close < mm_principal_Buffer[1])
               info_tende = "VENDA  ";
            else
               info_tende = "N/D    ";
         if(tendencia == 0)
            info_tende = "LATERAL";
         if(!filtroIFR && ifr_Buffer[1]>ifr_sobrecompra)
            info_ifr = "SOBRECOMPRADO";
         else
            if(!filtroIFR && ifr_Buffer[1]<ifr_sobrevenda)
               info_ifr = "SOBREVENDIDO ";
            else
               info_ifr = "OK           ";
         if(pavio == 0)
            info_fecha = "N/A  ";
         else
            if((pavioBom && rates[1].open < rates[1].close) || (pavioBom && rates[1].open > rates[1].close))
               info_fecha = "FORTE";
            else
               info_fecha = "FRACO";
         if(prop == 0)
            info_prop = "N/A ";
         else
            if((propBoa && rates[1].open < rates[1].close) || (propBoa && rates[1].open > rates[1].close))
               info_prop = "BOM ";
            else
               info_prop = "RUIM";
         if(!posAberta && !ordPendente)
            info_ordem = "Nenhuma posição aberta ou ordem pendente!";
         if(posAberta && ordPendente)
            info_ordem = "Posição ABERTA e ordem PENDENTE!";
         if(posAberta && !ordPendente)
           {
            string profitAtual = DoubleToString(PositionGetDouble(POSITION_PROFIT),2);
            string volumeAtual = DoubleToString(PositionGetDouble(POSITION_VOLUME),0);
            info_ordem = "Posição ABERTA: "+ volumeAtual +" R$"+ profitAtual;
           }
         if(!posAberta && ordPendente)
            info_ordem = "Ordem PENDENTE!";
         if(debug>1)
           {
            if(filtroSentTF || filtro_TouF)
              {
               string touf, info_touf;
               if(TouF)
                  touf = "Topo";
               else
                  if(!TouF)
                     touf = "Fundo";
               if(tende_touf == 0)
                  info_touf = "Sem alteração. Último: ";
               else
                  if(tende_touf == 1)
                     info_touf = "Máximos e mínimos ascendentes - Novo ";
                  else
                     if(tende_touf == 2)
                        info_touf = "Máximos e mínimos descendentes - Novo ";
                     else
                        if(tende_touf == 3)
                           info_touf = "Alargamento. Último: ";
               Print("Informações de Topos e Fundos: ", info_touf, touf, " / Negociação bloqueada? ", FiltroTouF);
               if(debug>2)
                 {
                  Print(">  Topo 1: ", Topo1, " /  Topo 2: ", Topo2, " /  Topo 3: ", Topo3);
                  Print(">  Fundo 1: ", Fundo1, " / Fundo 2: ", Fundo2, " / Fundo 3: ", Fundo3);
                  Print(">  Último Topo: ", UltimoTopo, " / Último Fundo: ", UltimoFundo, " / TouF: ", touf, " / Filtro TouF: ", FiltroTouF);
                 }
              }
            string info_prop_candle;
            if(rates[1].close>rates[1].open)
              {
               if(vela_minima < rates[1].high - rates[1].low && vela_minima*0.5 < rates[1].close - rates[1].open)
                  info_prop_candle = "@ Tamanho do candle bom";
               else
                  info_prop_candle = "# Candle menor que o mínimo definido";
               Print(info_prop_candle, " / Total: ", rates[1].high - rates[1].low, " Corpo: ", rates[1].close - rates[1].open,
                     " (", DoubleToString((((rates[1].high - rates[1].low)-(rates[1].close - rates[1].open))*100/(rates[1].high - rates[1].low)),0), "% de pavio) ", propBoa,
                     " / Pullback: ", rates[1].high-rates[1].close, " (", DoubleToString(((rates[1].high-rates[1].close)*100/(rates[1].high - rates[1].low)),0), "%) ", pavioBom);
              }
            else
               if(rates[1].close<rates[1].open)
                 {
                  if(vela_minima < rates[1].high - rates[1].low && vela_minima*0.5 < rates[1].open - rates[1].close)
                     info_prop_candle = "@ Tamanho do candle bom";
                  else
                     info_prop_candle = "# Candle menor que o mínimo definido";
                  Print(info_prop_candle, " / Total: ", rates[1].high - rates[1].low, " Corpo: ", rates[1].close - rates[1].low,
                        " (", DoubleToString((((rates[1].high - rates[1].low)-(rates[1].open - rates[1].close))*100/(rates[1].high - rates[1].low)),0), "% de pavio) ",propBoa,
                        " / Pullback: ", rates[1].close-rates[1].low, " (", DoubleToString(((rates[1].close-rates[1].low)*100/(rates[1].high - rates[1].low)),0), "%) ", pavioBom);
                 }
               else
                  Print("# Doji");
           }
         if(debug>4)
           {
            //Print("| Compras: PA: ", compra_pa, " / Tendência: ", compra_tende, " / MM: ", compra_mm_cross, " / Gift: ", compra_gift, " / IFR: ", compra_ifr_cross, " / Fundos: ", compra_lat);
            //Print("| Vendas:  PA: ", vende_pa, " / Tendência: ", vende_tende, " / MM: ", vende_mm_cross, " / Gift: ", vende_gift, " / IFR: ", vende_ifr_cross, " / Topos:  ", vende_lat);
           }
         Print("@ Candle ", info_prop, " ", info_vela, " / Fechamento ", info_fecha, " / Tendência ", info_tende, " / IFR ", info_ifr," / ", info_ordem);
        }
      // --- Fim do Debug
     }
  }

//+------------------------------------------------------------------+
//|                 FUNÇÃO VERIFICA NOVO CANDLE                      |
//+------------------------------------------------------------------+
bool TemosNovaVela()
  {
//--- cria variável de tempo atual
   static datetime last_time=0;
//--- memoriza o tempo de abertura da ultima barra (vela) numa variável
   datetime lastbar_time= iTime(Symbol(), mm_tempo_grafico, 0);
//--- se for a primeira chamada da função:
   if(last_time==0)
     {
      //--- atribuir valor temporal e sair
      last_time=lastbar_time;
      return(false);
     }
//--- se o tempo estiver diferente:
   if(last_time<lastbar_time)
     {
      //--- memorizar esse tempo e retornar true
      last_time=lastbar_time;
      return(true);
     }
//--- se passarmos desta linha, então a barra não é nova; retornar false
   return(false);
  }

//+------------------------------------------------------------------+
//|           FUNÇÃO PARA NEGOCIAÇÃO POR TENDÊNCIA                   |
//+------------------------------------------------------------------+
// LOGICA PARA ATIVAR COMPRA por tendencia
bool compra_tende()
  {
   if(rates[1].close>mm_principal_Buffer[1] && rates[1].open < rates[1].close && (rates[1].close>rates[2].open || rates[1].high-rates[1].low > rates[2].high-rates[2].low))
      return true;
   else
      return false;
  }
// LOGICA PARA ATIVAR VENDA por tendencia
bool vende_tende()
  {
   if(rates[1].close<mm_principal_Buffer[1] && rates[1].open > rates[1].close && (rates[1].close<rates[2].open || rates[1].high-rates[1].low > rates[2].high-rates[2].low))
      return true;
   else
      return false;
  }

//+------------------------------------------------------------------+
//|           FUNÇÃO PARA NEGOCIAÇÃO POR PRICE ACTION                |
//+------------------------------------------------------------------+
// LÓGICA DE COMPRA PRICE ACTION
bool compra_pa()
  {
   if(((rates[1].close > rates[2].high && rates[2].high - rates[2].low > rates[3].high - rates[3].low) || // Fechamento de vela1 acima do topo de vela2 e vela2 é maior que vela3
       (rates[1].close > rates[3].high && rates[2].high - rates[2].low < rates[3].high - rates[3].low) || // Fechamento de vela1 acima do topo de vela3 pois vela3 é maior que vela2
       (rates[1].close > rates[4].high && rates[2].high - rates[2].low < rates[3].high - rates[3].low &&
        rates[3].high - rates[3].low < rates[4].high - rates[4].low)))// Fechamento de vela1 acima do topo de vela4 pois vela4 é maior que vela3 que é maior que vela2
      return true;
   else
      return false;
  }
// LÓGICA DE VENDA PRICE ACTION
bool vende_pa()
  {
   if(((rates[1].close < rates[2].low && rates[2].high - rates[2].low > rates[3].high - rates[3].low) || // Fechamento de vela1 abaixo do fundo de vela2 e vela2 é maior que vela3
       (rates[1].close < rates[3].low && rates[2].high - rates[2].low < rates[3].high - rates[3].low) || // Fechamento de vela1 abaixo do fundo de vela3 pois vela3 é maior que vela2
       (rates[1].close < rates[4].low && rates[2].high - rates[2].low < rates[3].high - rates[3].low &&
        rates[3].high - rates[3].low < rates[4].high - rates[4].low))) // Fechamento de vela1 abaixo do fundo de vela4 pois vela4 é maior que vela3 que é maior que vela2
      return true;
   else
      return false;
  }

//+------------------------------------------------------------------+
//|           FUNÇÃO PARA NEGOCIAÇÃO POR CRUZAMENTO DE MÉDIAS        |
//+------------------------------------------------------------------+
// LOGICA PARA ATIVAR COMPRA por cruzamento de médias
bool compra_mm_cross()
  {
   if(mm_rapida_Buffer[0] > mm_lenta_Buffer[0] && mm_rapida_Buffer[2] < mm_lenta_Buffer[2] && rates[1].open < rates[1].close &&
      mm_rapida_Buffer[3]+rangeLateral*0.75 < mm_lenta_Buffer[3] && mm_rapida_Buffer[4]+rangeLateral < mm_lenta_Buffer[4] && mm_rapida_Buffer[5]+rangeLateral*1.25 < mm_lenta_Buffer[5])
      return true;
   else
      return false;
  }
// LÓGICA PARA ATIVAR VENDA por cruzamento de médias
bool vende_mm_cross()
  {
   if(mm_rapida_Buffer[0] < mm_lenta_Buffer[0] && mm_rapida_Buffer[2] > mm_lenta_Buffer[2] && rates[1].open > rates[1].close &&
      mm_rapida_Buffer[3]-rangeLateral*0.75 > mm_lenta_Buffer[3] && mm_rapida_Buffer[4]-rangeLateral > mm_lenta_Buffer[4] && mm_rapida_Buffer[5]-rangeLateral*1.25 > mm_lenta_Buffer[5])
      return true;
   else
      return false;
  }

//+------------------------------------------------------------------+
//|           FUNÇÃO PARA NEGOCIAÇÃO POR GIFT                        |
//+------------------------------------------------------------------+
// LOGICA PARA COMPRA POR GIFT
bool compra_gift()
  {
   if((rates[3].open < rates[3].close && // Candle3 positivo
       rates[1].open < rates[1].close && // Candle1 positivo
       rates[3].high > rates[2].high &&  // Topo da terceira barra anterior acima do topo da segunda e anterior
       rates[3].low < rates[2].low &&    // Fundo da terceira barra anterior abaixo da segunda e anterior
       rates[3].close-rates[3].open > rates[2].high-rates[2].low && // Corpo da terceira barra anterior maior que toda a segunda barra
       (rates[4].open < rates[4].close || rates[3].close-rates[3].open > rates[4].open-rates[4].close) && // Corpo do candle3 maior que do candle4
       rates[2].low > rates[3].open &&   // Fundo da vela negativa não passa da abertura da terceira vela anterior
       rates[1].close > rates[3].high && // O fechamento do candle1 é acima do topo do candle3
       rates[1].high-rates[1].close < rates[2].high-rates[2].low && // O pullback do candle1 é menor que o candle2
       rates[1].high-rates[1].close < rates[1].close-rates[1].low)) // Pullback do candle1 menor que o resto do candle1
      return true;
   else
      return false;
  }
// LOGICA PARA VENDA POR GIFT
bool vende_gift()
  {
   if((rates[3].open > rates[3].close &&  // Terceira vela anterior negativa
       rates[1].open > rates[1].close &&  // vela anterior negativa
       rates[3].high > rates[2].high &&   // Topo da terceira barra anterior acima do topo da segunda e ultima barra
       rates[3].low < rates[2].low &&     // Fundo da terceira barra anterior abaixo do fundo da segunda e ultima barra
       rates[3].open-rates[3].close > rates[2].high-rates[2].low && // Corpo da terceira vela anterior maior que a segunda
       (rates[4].open > rates[4].close || rates[3].open-rates[3].close > rates[4].close-rates[4].open) && // Corpo do candle3 maior que do candle4
       rates[2].high < rates[3].open &&     // Topo da vela positiva não passa da abertura da terceira vela anterior
       rates[1].close < rates[3].low && // O fechamento do candle1 é abaixo do fundo do candle3
       rates[1].close-rates[1].low < rates[2].high-rates[2].low && // O pullback do candle1 é menor que o candle2
       rates[1].close-rates[1].low < rates[1].high-rates[1].close)) // Pullback do candle1 menor que o resto do candle1
      return true;
   else
      return false;
  }

//+------------------------------------------------------------------+
//|           FUNÇÃO PARA NEGOCIAÇÃO POR CRUZAMENTO DE IFR           |
//+------------------------------------------------------------------+
// LOGICA DE COMPRA POR CRUZAMENTO DE IFR
bool compra_ifr_cross()
  {
   if(ifr_Buffer[2] < ifr_sobrevenda  && ifr_Buffer[1] > ifr_sobrevenda && (ifr_Buffer[0] < 50 && ifr_Buffer[0] < ifr_sobrecompra*0.5))
      return true;
   else
      return false;
  }
// LOGICA DE VENDA POR CRUZAMENTO DE IFR
bool vende_ifr_cross()
  {
   if(ifr_Buffer[2] > ifr_sobrecompra  && ifr_Buffer[1] < ifr_sobrecompra && (ifr_Buffer[0] > 50 && ifr_Buffer[0] > ifr_sobrevenda*2))
      return true;
   else
      return false;
  }

//+------------------------------------------------------------------+
//|           FUNÇÃO PARA NEGOCIAÇÃO EM LATERALIDADES                |
//+------------------------------------------------------------------+
void Lateral(bool pavioBom, bool propBoa, bool timetotrade)
  {
// LOGICA PARA COMPRA POR LATERALIDADE (Compra fundos)
   bool compra_lat = rates[1].open > rates[1].close && (rates[1].open - rates[1].close < rangeLateral*2 || rates[1].open - rates[1].close < rates[1].close - rates[1].low) && // Barra anterior negativa, de corpo menor que o dobro do range de lateralidade ou o pavio inferior
                     mm_rapida_Buffer[1]-rangeLateral/5 > rates[1].close && rates[1].close > mm_rapida_Buffer[1]-rangeLateral*2 && // Fechamento da vela abaixo da média rápida, mas nem tão abaixo
                     (rates[1].high > mm_rapida_Buffer[1] || rates[2].high > mm_rapida_Buffer[2]) && // Candle1 ou candle2 tocam a média rápida
                     (rates[2].open<rates[2].close || rates[3].open<rates[3].close) && // Penultima ou antepenultima barra positiva
                     rates[1].close-stopLossMin<rates[2].low &&   // Fechamento da ultima barra menos stopminimo > minimo da barra anterior -- não teria sido stopado nas barras anteriores
                     rates[1].close-stopLossMin<rates[3].low &&
                     rates[1].close-stopLossMin<rates[4].low &&
                     rates[1].close-stopLossMin<rates[5].low &&
                     rates[1].close<rates[2].low+rangeLateral && // Fechamento da ultima barra < minimo da barra anterior mais o range de lateralidade -- Não fechou no meio da lateralidade
                     rates[1].close>rates[2].low-rangeLateral && // Fechamento da ultima barra > minimo da barra anterior menos o range de lateralidade -- Não está rompendo a lateralidade
                     (!propBoa || !pavioBom || rates[1].close - rates[1].low > (rates[1].high -rates[1].close)/4) && vela_minima < rates[1].high - rates[1].low; // Vela com tamanho mínimo e com algum pullback

// LOGICA PARA VENDA POR LATERALIDADE (Vende topos)
   bool vende_lat = rates[1].open < rates[1].close && (rates[1].close - rates[1].open < rangeLateral*2 || rates[1].close - rates[1].open < rates[1].high - rates[1].close) && // Barra anterior positiva,  de corpo menor que o dobro do range de lateralidade ou pavio superior
                    mm_rapida_Buffer[1]+rangeLateral/5 < rates[1].close && rates[1].close < mm_rapida_Buffer[1]+rangeLateral*2 && // Fechamento da vela acima da média rápida, mas nem tão acima
                    (rates[1].low < mm_rapida_Buffer[1] || rates[2].low < mm_rapida_Buffer[2]) && // Candle1 ou candle2 tocam a média rápida
                    (rates[2].open>rates[2].close || rates[3].open>rates[3].close) && // Penúltima ou antepenúltima barra negativa
                    rates[1].close+stopLossMin>rates[2].high && // Fechamento da ultima barra mais stop minimo > maximo da barra anterior -- não teria sido stopado nas barras anteriores
                    rates[1].close+stopLossMin>rates[3].high &&
                    rates[1].close+stopLossMin>rates[4].high &&
                    rates[1].close+stopLossMin>rates[5].high &&
                    rates[1].close>rates[2].high-rangeLateral && // Fechamento da ultima barra > máximo da barra anterior menos o range de lateralidade -- Não fechou no meio da lateralidade
                    rates[1].close<rates[2].high+rangeLateral && // Fechamento da ultima barra < máximo da barra anterior mais o range de lateralidade -- Não está rompendo a lateralidade
                    (!propBoa || !pavioBom || rates[1].high - rates[1].close > (rates[1].close -rates[1].low)/4) && vela_minima < rates[1].high - rates[1].low; // Vela com tamanho mínimo e com algum pullback
   if(debug>3)
      Print("Negociação por Mercado LATERAL!");
   double loteNeg = MathCeil(lotemin); //Meio lote para negociação em lateralidades e por IFR
   if(lote>lotemin*2)
      loteNeg = MathFloor(lote/2);
   if(compra_lat)
     {
      ordemComment = "Compra FUNDO";
      CalculosCompra();
     }
   if(vende_lat)
     {
      ordemComment = "Venda TOPO";
      CalculosVenda();
     }
  }

//+------------------------------------------------------------------+
//|           FUNÇÃO PARA CÁLCULO DE STOP LOSS DE COMPRA             |
//+------------------------------------------------------------------+
void CalculosCompra()
  {
   bool temrestricao = restricao(); //
   double loteNeg = lote;
   double PRC = NormalizeDouble(tick.ask, _Digits);
   double STL = NormalizeDouble(PRC - stopLossMin, _Digits);
//double TKP = NormalizeDouble(MathRound(((PRC-STL)*takeProfit)/ticSize)*ticSize,_Digits);
   if((TipoStop == 0 && stopLossMax>atr_Buffer[1]*constATR)||(alinhax2 && ordemComment == "Alinhamento de Compra"))
     {
      STL = NormalizeDouble(MathRound((PRC-(atr_Buffer[1]*constATR))/ticSize)*ticSize,_Digits);
      //TKP = NormalizeDouble(MathRound((PRC+(atr_Buffer[1]*constATR*takeProfit))/ticSize)*ticSize,_Digits);
      if(debug>2)
         Print("Take Profit e Stop Loss ajustados por ATR!");
     }
   if(TipoStop == 1)
      STL = NormalizeDouble(PRC - stopLossMin, _Digits);
   if(TipoStop == 2 || (tendencia == 0 && lateraltrade && Esp_Stop != 1) || (temrestricao) ||
      (Esp_Stop == 2 && (ordemComment == "Compra Gift" || ordemComment == "Compra PA")))
     {
      if(rates[3].low < rates[2].low && rates[2].low < rates[1].low && nivelStop>2)
         STL = NormalizeDouble(rates[3].low, _Digits);
      else
         if((rates[2].low < rates[1].low) && (nivelStop>1))
            STL = NormalizeDouble(rates[2].low, _Digits);
         else
            if(nivelStop>0)
               STL = NormalizeDouble(rates[1].low, _Digits);
            else
               STL = NormalizeDouble(rates[0].low, _Digits);
     }
   else
      if(TipoStop == 3)
        {
         if(nivelStop == 1)
           {
            STL = NormalizeDouble(MathRound(mm_rapida_Buffer[1]/ticSize)*ticSize,_Digits);
            if(STL > PRC)
               STL = NormalizeDouble(PRC - stopLossMin, _Digits);
           }
         else
            if(nivelStop == 2)
              {
               STL = NormalizeDouble(MathRound(mm_rapida_Buffer[2]/ticSize)*ticSize,_Digits);
               if(STL > PRC)
                  STL = NormalizeDouble(PRC - stopLossMin, _Digits);
              }
            else
               if(nivelStop == 3)
                 {
                  STL = NormalizeDouble(MathRound(mm_rapida_Buffer[3]/ticSize)*ticSize,_Digits);
                  if(STL > PRC)
                     STL = NormalizeDouble(PRC - stopLossMin, _Digits);
                 }
               else
                  if(nivelStop == 0)
                    {
                     STL = NormalizeDouble(MathRound(mm_rapida_Buffer[0]/ticSize)*ticSize,_Digits);
                     if(STL > PRC)
                        STL = NormalizeDouble(PRC - stopLossMin, _Digits);
                    }
        }
      else
         if(TipoStop == 4)
           {
            if(nivelStop == 1)
              {
               STL = NormalizeDouble(MathRound(mm_lenta_Buffer[1]/ticSize)*ticSize,_Digits);
               if(STL > PRC)
                  STL = NormalizeDouble(MathRound(PRC-(STL-PRC)/ticSize)*ticSize,_Digits);
               if(STL<stopLossMin)
                  STL = NormalizeDouble(PRC - stopLossMin, _Digits);
              }
            else
               if(nivelStop == 2)
                 {
                  STL = NormalizeDouble(MathRound(mm_lenta_Buffer[2]/ticSize)*ticSize,_Digits);
                  if(STL > PRC)
                     STL = NormalizeDouble(MathRound(PRC-(STL-PRC)/ticSize)*ticSize,_Digits);
                  if(STL<stopLossMin)
                     STL = NormalizeDouble(PRC - stopLossMin, _Digits);
                 }
               else
                  if(nivelStop == 3)
                    {
                     STL = NormalizeDouble(MathRound(mm_lenta_Buffer[3]/ticSize)*ticSize,_Digits);
                     if(STL > PRC)
                        STL = NormalizeDouble(MathRound(PRC-(STL-PRC)/ticSize)*ticSize,_Digits);
                     if(STL<stopLossMin)
                        STL = NormalizeDouble(PRC - stopLossMin, _Digits);
                    }
                  else
                     if(nivelStop == 0)
                       {
                        STL = NormalizeDouble(MathRound(mm_lenta_Buffer[0]/ticSize)*ticSize,_Digits);
                        if(STL > PRC)
                           STL = NormalizeDouble(MathRound(PRC-(STL-PRC)/ticSize)*ticSize,_Digits);
                        if(STL<stopLossMin)
                           STL = NormalizeDouble(PRC - stopLossMin, _Digits);
                       }
           }
   if((Esp_Stop == 1 && (ordemComment == "Compra Gift" || ordemComment == "Compra FUNDO" || ordemComment == "Compra IFR" || ordemComment == "Compra PA"))||
      (Esp_Stop == 2 && (ordemComment == "Compra FUNDO" || ordemComment == "Compra IFR")))
     {
      STL = NormalizeDouble(MathRound((PRC-(atr_Buffer[1]))/ticSize)*ticSize,_Digits);
      if(debug>2)
         Print("Take Profit e Stop Loss ajustados por ATR!");
     }
//TKP = NormalizeDouble(MathRound(((PRC-STL)*takeProfit)/ticSize)*ticSize,_Digits);
   loteNeg = lote;
   if(alinhax2 && ordemComment == "Alinhamento de Compra")
      loteNeg = lote*2;
   if(temrestricao || ordemComment == "Compra FUNDO")
     {
      if(loteNeg>lotemin*2)
         loteNeg = MathFloor(lote/2);
      else
         loteNeg = MathCeil(lotemin); //Lote para negociação com restrições
     }
//Bloqueia operação com excesso de volatilidade
   if(TipoStop!=0 || stopLossMax>atr_Buffer[1]*constATR)
      Compra(PRC,STL,loteNeg);
   else
      if(debug>2)
         Print("# Compra bloqueada, limite de volatilidade excedido!");
  }

//+------------------------------------------------------------------+
//|           FUNÇÃO PARA CÁLCULO DE STOP LOSS DE VENDA              |
//+------------------------------------------------------------------+
void CalculosVenda()
  {
   bool temrestricao = restricao(); //
   double loteNeg = lote;
   double PRC = NormalizeDouble(tick.bid, _Digits);
   double STL = NormalizeDouble(PRC + stopLossMin, _Digits);
   if((TipoStop == 0 && stopLossMax > atr_Buffer[1]*constATR)||(alinhax2 && ordemComment == "Alinhamento de Venda"))
     {
      STL = NormalizeDouble(MathRound((PRC+(atr_Buffer[1]*constATR))/ticSize)*ticSize,_Digits);
      if(debug>2)
         Print("Take Profit e Stop Loss ajustados por ATR!");
     }
   if(TipoStop == 1)
      STL = NormalizeDouble(PRC + stopLossMin, _Digits);
   if(TipoStop == 2 || (tendencia == 0 && lateraltrade && Esp_Stop != 1) || (temrestricao) ||
      (Esp_Stop == 2 && (ordemComment == "Venda Gift" || ordemComment == "Venda PA")))
     {
      if(rates[3].high > rates[2].high && rates[2].high > rates[1].high && nivelStop>2)
         STL = NormalizeDouble(rates[3].high, _Digits);
      else
         if((rates[2].high > rates[1].high) && (nivelStop>1))
            STL = NormalizeDouble(rates[2].high, _Digits);
         else
            if(nivelStop>0)
               STL = NormalizeDouble(rates[1].high, _Digits);
            else
               STL = NormalizeDouble(rates[0].high, _Digits);
     }
   else
      if(TipoStop == 3)
        {
         if(nivelStop == 1)
           {
            STL = NormalizeDouble(MathRound(mm_rapida_Buffer[1]/ticSize)*ticSize,_Digits);
            if(STL < PRC)
               STL = NormalizeDouble(PRC + stopLossMin, _Digits);
           }
         else
            if(nivelStop == 2)
              {
               STL = NormalizeDouble(MathRound(mm_rapida_Buffer[2]/ticSize)*ticSize,_Digits);
               if(STL < PRC)
                  STL = NormalizeDouble(PRC + stopLossMin, _Digits);
              }
            else
               if(nivelStop == 3)
                 {
                  STL = NormalizeDouble(MathRound(mm_rapida_Buffer[3]/ticSize)*ticSize,_Digits);
                  if(STL < PRC)
                     STL = NormalizeDouble(PRC + stopLossMin, _Digits);
                 }
               else
                  if(nivelStop == 0)
                    {
                     STL = NormalizeDouble(MathRound(mm_rapida_Buffer[0]/ticSize)*ticSize,_Digits);
                     if(STL < PRC)
                        STL = NormalizeDouble(PRC + stopLossMin, _Digits);
                    }
        }
      else
         if(TipoStop == 4)
           {
            if(nivelStop == 1)
              {
               STL = NormalizeDouble(MathRound(mm_lenta_Buffer[1]/ticSize)*ticSize,_Digits);
               if(STL < PRC)
                  STL = NormalizeDouble(MathRound(PRC+(PRC-STL)/ticSize)*ticSize,_Digits);
               if(STL<stopLossMin)
                  STL = NormalizeDouble(PRC + stopLossMin, _Digits);
              }
            else
               if(nivelStop == 2)
                 {
                  STL = NormalizeDouble(MathRound(mm_lenta_Buffer[2]/ticSize)*ticSize,_Digits);
                  if(STL < PRC)
                     STL = NormalizeDouble(MathRound(PRC+(PRC-STL)/ticSize)*ticSize,_Digits);
                  if(STL<stopLossMin)
                     STL = NormalizeDouble(PRC + stopLossMin, _Digits);
                 }
               else
                  if(nivelStop == 3)
                    {
                     STL = NormalizeDouble(MathRound(mm_lenta_Buffer[3]/ticSize)*ticSize,_Digits);
                     if(STL < PRC)
                        STL = NormalizeDouble(MathRound(PRC+(PRC-STL)/ticSize)*ticSize,_Digits);
                     if(STL<stopLossMin)
                        STL = NormalizeDouble(PRC + stopLossMin, _Digits);
                    }
                  else
                     if(nivelStop == 0)
                       {
                        STL = NormalizeDouble(MathRound(mm_lenta_Buffer[0]/ticSize)*ticSize,_Digits);
                        if(STL < PRC)
                           STL = NormalizeDouble(MathRound(PRC+(PRC-STL)/ticSize)*ticSize,_Digits);
                        if(STL<stopLossMin)
                           STL = NormalizeDouble(PRC + stopLossMin, _Digits);
                       }
           }
   if((Esp_Stop == 1 && (ordemComment == "Venda Gift" || ordemComment == "Venda TOPO" || ordemComment == "Venda IFR" || ordemComment == "Venda PA"))||
      (Esp_Stop == 2 && (ordemComment == "Venda TOPO" || ordemComment == "Venda IFR")))
     {
      STL = NormalizeDouble(MathRound((PRC+(atr_Buffer[1]))/ticSize)*ticSize,_Digits);
      if(debug>2)
         Print("Take Profit e Stop Loss ajustados por ATR!");
     }
//TKP = NormalizeDouble(MathRound(((STL-PRC)*takeProfit)/ticSize)*ticSize,_Digits);
   loteNeg = lote;
   if(alinhax2 && ordemComment == "Alinhamento de Venda")
      loteNeg = lote*2;
   if(temrestricao || ordemComment == "Venda TOPO")
     {
      if(loteNeg>lotemin*2)
         loteNeg = MathFloor(lote/2);
      else
         loteNeg = MathCeil(lotemin); //Lote para negociação com restrições
     }
//Bloqueia operação com excesso de volatilidade
   if(TipoStop!=0 || stopLossMax>atr_Buffer[1]*constATR)
      Vende(PRC,STL,loteNeg);
   else
      if(debug>2)
         Print("# Venda bloqueada, limite de volatilidade excedido!");
  }

//+------------------------------------------------------------------+
//|                      FUNÇÃO COMPRA                               |
//+------------------------------------------------------------------+
void Compra(double PRC, double STL, double loteNeg)
  {
   if(debug>3)
      Print("Função de compra chamada!");
   if(!licenca)
      Print("# Compra bloqueada! Licença de testes vencida!");
   else
     {
      if(!posAberta)
        {
         if((STL < Fundo1+stopLossMin && STL > Fundo1-stopLossMin/5 && Fundo1 != 0)||(STL < Fundo2+stopLossMin*0.75 && STL > Fundo2-stopLossMin/5 && Fundo2 != 0)||(STL < Fundo3+stopLossMin*0.5 && STL > Fundo3-stopLossMin/5 && Fundo3 != 0) ||
            (STL < Topo1+stopLossMin && STL > Topo1-stopLossMin/5 && Fundo1 != 0)||(STL < Topo2+stopLossMin*0.75 && STL > Topo2-stopLossMin/5 && Fundo2 != 0)||(STL < Topo3+stopLossMin*0.5 && STL > Topo3-stopLossMin/5 && Fundo3 != 0))
           {
            STL = STL - stepTS;
            if(debug>2)
               Print("Stop ajustado devido a proximidade com Topos ou Fundos!");
            Compra(PRC, STL, loteNeg);
            return;
           }
         //PRC = NormalizeDouble(tick.ask, _Digits);
         double TKP = NormalizeDouble(PRC + (PRC - STL) * takeProfit, _Digits);
         if(STL < PRC - stopLossMax)
            STL = NormalizeDouble(PRC - stopLossMax, _Digits);
         if(STL > PRC - stopLossMin)
            STL = NormalizeDouble(PRC - stopLossMin, _Digits);
         if(lateraltrade && tendencia == 0)
            TKP = NormalizeDouble(PRC + (PRC - STL), _Digits);
         else
            TKP = NormalizeDouble(PRC + (PRC - STL) * takeProfit, _Digits);

         if(d_trade.Buy(loteNeg, _Symbol, PRC, STL, TKP, ordemComment))
           {
            posAberta = true;
            if(debug>0)
               Print("$ Ordem de ", ordemComment, " - ** OK **. ResultRetcode: ", d_trade.ResultRetcode(), ", RetcodeDescription: ", d_trade.ResultRetcodeDescription());
            ordemComment = "Compra já execultada - Verificar ERRO!";
           }
         else
            if(debug>0)
               Print("Ordem de Compra - * FALHOU *. ResultRetcode: ", d_trade.ResultRetcode(), ", RetcodeDescription: ", d_trade.ResultRetcodeDescription());
        }
     }
  }

//+------------------------------------------------------------------+
//|                        FUNÇÃO VENDA                              |
//+------------------------------------------------------------------+
void Vende(double PRC, double STL, double loteNeg)
  {
   if(debug>3)
      Print("Função de Venda chamada!");
   if(!licenca)
      Print("# Venda Bloqueada! Licença de testes vencida!");
   else
     {
      if(!vendido && debug>2)
         Print("Venda Bloqueada! Negociação de posição vendida desativada!");
      else
        {
         if(!posAberta)
           {
            if((STL < Topo1+stopLossMin/5 && STL > Topo1-stopLossMin && Fundo1 != 0)||(STL < Topo2+stopLossMin/5 && STL > Topo2-stopLossMin*0.75 && Fundo2 != 0)||(STL < Topo3+stopLossMin/5 && STL > Topo3-stopLossMin*0.5 && Fundo3 != 0) ||
               (STL < Fundo1+stopLossMin/5 && STL > Fundo1-stopLossMin && Fundo1 != 0)||(STL < Fundo2+stopLossMin/5 && STL > Fundo2-stopLossMin*0.75 && Fundo2 != 0)||(STL < Fundo3+stopLossMin/5 && STL > Fundo3-stopLossMin*0.5 && Fundo3 != 0))
              {
               STL = STL + stepTS;
               if(debug>2)
                  Print("Stop ajustado devido a proximidade com Topos ou Fundos!");
               Vende(PRC, STL, loteNeg);
               return;
              }
            //PRC = NormalizeDouble(tick.bid, _Digits);
            double TKP = NormalizeDouble(PRC - (STL - PRC) * takeProfit, _Digits);
            if(STL > PRC + stopLossMax)
               STL = NormalizeDouble(PRC + stopLossMax, _Digits);
            if(STL < PRC + stopLossMin)
               STL = NormalizeDouble(PRC + stopLossMin, _Digits);
            if(lateraltrade && tendencia == 0)
               TKP = NormalizeDouble(PRC - (STL - PRC), _Digits);
            else
               TKP = NormalizeDouble(PRC - (STL - PRC) * takeProfit, _Digits);
            if(d_trade.Sell(loteNeg, _Symbol, PRC, STL, TKP, ordemComment))
              {
               posAberta = true;
               if(debug>0)
                  Print("$ Ordem de ", ordemComment, " - ** OK **. ResultRetcode: ", d_trade.ResultRetcode(), ", RetcodeDescription: ", d_trade.ResultRetcodeDescription());
               ordemComment = "Venda já execultada - Verificar ERRO!";
              }
            else
               if(debug>0)
                  Print("Ordem de Venda - * FALHOU *. ResultRetcode: ", d_trade.ResultRetcode(), ", RetcodeDescription: ", d_trade.ResultRetcodeDescription());
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                         BREAKEVEN                                |
//+------------------------------------------------------------------+
void BreakEven(double precoAsk, double precoBid, bool NovaVela)
  {
   if(debug>3 && NovaVela)
      Print("BreakEven chamado para verificação!");
   double TPC;
   double PE;
   for(int i = PositionsTotal()-1; i>=0; i--)
     {
      string symbol = PositionGetSymbol(i);
      ulong magic = PositionGetInteger(POSITION_MAGIC);
      if(symbol == _Symbol && magic == magicNum)
        {
         ulong PositionTicket = PositionGetInteger(POSITION_TICKET);
         double PrecoEntrada = PositionGetDouble(POSITION_PRICE_OPEN);
         double StopLossCorrente = PositionGetDouble(POSITION_SL);
         double TakeProfitCorrente = PositionGetDouble(POSITION_TP);
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
           {
            if(precoAsk>=PrecoEntrada+gatilhoBE||(tendencia == 0&&precoAsk>=PrecoEntrada+gatilhoBE/2))
              {
               PE = NormalizeDouble(MathCeil((PrecoEntrada+ajusteBE)/ticSize)*ticSize,_Digits);
               TPC = NormalizeDouble(MathRound(TakeProfitCorrente/ticSize)*ticSize,_Digits);
               if(tendencia == 0)
                  PE = NormalizeDouble(MathCeil((PrecoEntrada+ticSize)/ticSize)*ticSize,_Digits);
               if(StopLossCorrente >= PE)
                 {
                  beAtivo = true;
                  break;
                 }
               if(d_trade.PositionModify(PositionTicket, PE, TPC))
                 {
                  Print("BreakEven - ** OK **. ResultRetcode: ", d_trade.ResultRetcode(), ", RetcodeDescription: ", d_trade.ResultRetcodeDescription());
                  beAtivo = true;
                  break;
                 }
               else
                  if(debug>1 && NovaVela)
                    {
                     Print("BreakEven - com falha. ResultRetcode: ", d_trade.ResultRetcode(), ", RetcodeDescription: ", d_trade.ResultRetcodeDescription());
                     if(debug>2)
                        Print("PositionTicket: ", PositionTicket, " Preço atual: ", precoAsk, " Preço de entrada e BreakEven pretendido (PE): ", PE, " Take Profit (TPC): ", TPC);
                    }
              }
           }
         else
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
              {
               if(precoBid<=PrecoEntrada-gatilhoBE||(tendencia == 0&&precoBid<=PrecoEntrada-gatilhoBE/2))
                 {
                  PE = NormalizeDouble(MathFloor((PrecoEntrada-ajusteBE)/ticSize)*ticSize,_Digits);
                  TPC = NormalizeDouble(MathRound(TakeProfitCorrente/ticSize)*ticSize,_Digits);
                  if(tendencia == 0)
                     PE = NormalizeDouble(MathFloor((PrecoEntrada-ticSize)/ticSize)*ticSize,_Digits);
                  if(StopLossCorrente <= PE)
                    {
                     beAtivo = true;
                     break;
                    }
                  if(d_trade.PositionModify(PositionTicket, PE, TPC))
                    {
                     Print("BreakEven - ** OK **. ResultRetcode: ", d_trade.ResultRetcode(), ", RetcodeDescription: ", d_trade.ResultRetcodeDescription());
                     beAtivo = true;
                    }
                  else
                     if(debug>1 && NovaVela)
                       {
                        Print("BreakEven - com falha. ResultRetcode: ", d_trade.ResultRetcode(), ", RetcodeDescription: ", d_trade.ResultRetcodeDescription());
                        if(debug>2)
                           Print("PositionTicket: ", PositionTicket, " Preço atual: ", precoBid, " Preço de entrada e BreakEven pretendido (PE): ", PE, " Take Profit (TPC): ", TPC);
                       }
                 }
              }
        }
     }
  }

//+------------------------------------------------------------------+
//|                         TRAILING STOP                            |
//+------------------------------------------------------------------+
void TrailingStop(double precoAsk, double precoBid, bool NovaVela)
  {
   if(debug>3 && NovaVela)
      Print("TraingStop chamado para verificação!");
   for(int i = PositionsTotal()-1; i>=0; i--)
     {
      string symbol = PositionGetSymbol(i);
      ulong magic = PositionGetInteger(POSITION_MAGIC);
      if(symbol == _Symbol && magic==magicNum)
        {
         ulong PositionTicket = PositionGetInteger(POSITION_TICKET);
         double StopLossCorrente = PositionGetDouble(POSITION_SL);
         double TakeProfitCorrente = PositionGetDouble(POSITION_TP);
         double PrecoEntrada = PositionGetDouble(POSITION_PRICE_OPEN);
         double PRC = tick.bid;
         double TPC = TakeProfitCorrente;
         double STL = StopLossCorrente;
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
           {
            if(precoAsk >= (StopLossCorrente+gatilhoTS)||(tendencia == 0 && lateraltrade && precoAsk >= StopLossCorrente + gatilhoTS/2))
              {
               if(lateraltrade && tendencia == 0)
                  STL = NormalizeDouble(MathCeil((PRC-stepTS/2)/ticSize)*ticSize,_Digits);
               else
                  if(TipoTrail == 4)
                    {
                     if(PRC < PrecoEntrada + stopLossMin+ajusteBE) //Stop Fixo até Stop minimo+breakeven
                        STL = NormalizeDouble(PRC-stepTS,_Digits);
                     else
                        if(PRC < PrecoEntrada + (stopLossMin+ajusteBE)*2)
                           STL = NormalizeDouble(PRC-stepTS*2,_Digits);
                        else
                           if(rates[1].open < rates[1].close)
                             {
                              if(rates[3].low < rates[2].low && rates[2].low < rates[1].low)
                                 STL = NormalizeDouble(rates[3].low, _Digits);
                              else
                                 if(rates[2].low < rates[1].low)
                                    STL = NormalizeDouble(rates[2].low, _Digits);
                                 else
                                    STL = NormalizeDouble(rates[1].low, _Digits);
                              STL = NormalizeDouble(MathCeil((STL)/ticSize)*ticSize,_Digits);
                             }
                    }
                  else
                     if(TipoTrail == 2)
                       {
                        if(nivelTStop == 1 && StopLossCorrente<mm_rapida_Buffer[1])
                           STL = NormalizeDouble(MathRound(mm_rapida_Buffer[1]/ticSize)*ticSize,_Digits);
                        if(nivelTStop == 2 && StopLossCorrente<mm_rapida_Buffer[2])
                           STL = NormalizeDouble(MathRound(mm_rapida_Buffer[2]/ticSize)*ticSize,_Digits);
                        if(nivelTStop == 3 && StopLossCorrente<mm_rapida_Buffer[3])
                           STL = NormalizeDouble(MathRound(mm_rapida_Buffer[3]/ticSize)*ticSize,_Digits);
                        if(nivelTStop == 0 && StopLossCorrente<mm_rapida_Buffer[0])
                           STL = NormalizeDouble(MathRound(mm_rapida_Buffer[0]/ticSize)*ticSize,_Digits);
                       }
                     else
                        if(TipoTrail == 3)
                          {
                           if(nivelTStop == 1 && StopLossCorrente<mm_lenta_Buffer[1])
                              STL = NormalizeDouble(MathRound((mm_lenta_Buffer[1])/ticSize)*ticSize,_Digits);
                           if(nivelTStop == 2 && StopLossCorrente<mm_lenta_Buffer[2])
                              STL = NormalizeDouble(MathRound((mm_lenta_Buffer[2])/ticSize)*ticSize,_Digits);
                           if(nivelTStop == 3 && StopLossCorrente<mm_lenta_Buffer[3])
                              STL = NormalizeDouble(MathRound((mm_lenta_Buffer[3])/ticSize)*ticSize,_Digits);
                           if(nivelTStop == 0 && StopLossCorrente<mm_lenta_Buffer[0])
                              STL = NormalizeDouble(MathRound((mm_lenta_Buffer[0])/ticSize)*ticSize,_Digits);
                          }
                        else
                           if(TipoTrail == 0 && (!lateraltrade || tendencia != 0) && precoAsk-stopLossMax<rates[1].close)
                             {
                              if(rates[1].open < rates[1].close)
                                {
                                 if(rates[3].low < rates[2].low && rates[2].low < rates[1].low && nivelTStop > 2)
                                    STL = NormalizeDouble(rates[3].low, _Digits);
                                 else
                                    if((rates[2].low < rates[1].low) && (nivelTStop > 1))
                                       STL = NormalizeDouble(rates[2].low, _Digits);
                                    else
                                       if(nivelTStop>0)
                                          STL = NormalizeDouble(rates[1].low, _Digits);
                                       else
                                          STL = NormalizeDouble((rates[0].low-stepTS), _Digits);
                                 STL = NormalizeDouble(MathCeil((STL)/ticSize)*ticSize,_Digits);
                                }
                              else
                                {
                                 if(debug>2 && NovaVela)
                                    Print("Vela Negativa, nada a fazer!");
                                }
                             }
               if(TipoTrail == 1 || STL >= precoAsk)
                  STL = NormalizeDouble(PRC-stepTS,_Digits);
               if(STL >= StopLossCorrente+ticSize && STL !=0)
                 {
                  if(d_trade.PositionModify(PositionTicket, STL, TPC) && debug>1)
                     Print("TrailingStop - ** OK **. ResultRetcode: ", d_trade.ResultRetcode(), ", RetcodeDescription: ", d_trade.ResultRetcodeDescription());
                  else
                     if(debug>1 && NovaVela)
                       {
                        Print("TrailingStop - com falha. ResultRetcode: ", d_trade.ResultRetcode(), ", RetcodeDescription: ", d_trade.ResultRetcodeDescription());
                        if(debug>2)
                           Print("Stoploss atual: ", StopLossCorrente, " Stoploss pretendido: ", STL, " Preço atual: ", PRC);
                       }
                 }
               else
                  if(debug>2 && NovaVela)
                     Print("Trailing RECUSADO! Novo stop pior que stop atual!");
              }
           }
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
           {
            if(precoBid <= (StopLossCorrente - gatilhoTS) || (tendencia == 0 && lateraltrade && precoBid <= StopLossCorrente + gatilhoTS/2))
              {
               if(lateraltrade && tendencia == 0)
                  STL = NormalizeDouble(MathCeil((PRC+stepTS/2)/ticSize)*ticSize,_Digits);
               else
                  if(TipoTrail == 4)
                    {
                     //Stop Fixo até Stop minimo
                     if(PRC > PrecoEntrada - stopLossMin)
                        STL = NormalizeDouble(PRC+stepTS,_Digits);
                     else
                        if(PRC > PrecoEntrada - stopLossMin*2)
                          {
                           if(rates[1].open > rates[1].close)
                              STL = NormalizeDouble(rates[1].high, _Digits);
                          }
                        else
                           if(rates[1].open > rates[1].close)
                             {
                              if(rates[3].high > rates[2].high && rates[2].high > rates[1].high)
                                 STL = NormalizeDouble(rates[3].high, _Digits);
                              else
                                 if(rates[2].high > rates[1].high)
                                    STL = NormalizeDouble(rates[2].high, _Digits);
                                 else
                                    STL = NormalizeDouble(rates[1].high, _Digits);
                              STL = NormalizeDouble(MathCeil((STL)/ticSize)*ticSize,_Digits);
                             }
                    }
                  else
                     if(TipoTrail == 2)
                       {
                        if(nivelTStop == 1 && StopLossCorrente>mm_rapida_Buffer[1])
                           STL = NormalizeDouble(MathRound(mm_rapida_Buffer[1]/ticSize)*ticSize,_Digits);
                        if(nivelTStop == 2 && StopLossCorrente>mm_rapida_Buffer[2])
                           STL = NormalizeDouble(MathRound(mm_rapida_Buffer[2]/ticSize)*ticSize,_Digits);
                        if(nivelTStop == 3 && StopLossCorrente>mm_rapida_Buffer[3])
                           STL = NormalizeDouble(MathRound(mm_rapida_Buffer[3]/ticSize)*ticSize,_Digits);
                        if(nivelTStop == 0 && StopLossCorrente>mm_rapida_Buffer[0])
                           STL = NormalizeDouble(MathRound(mm_rapida_Buffer[0]/ticSize)*ticSize,_Digits);
                       }
                     else
                        if(TipoTrail == 3)
                          {
                           if(nivelTStop == 1 && StopLossCorrente>mm_lenta_Buffer[1])
                              STL = NormalizeDouble(MathRound((mm_lenta_Buffer[1])/ticSize)*ticSize,_Digits);
                           if(nivelTStop == 2 && StopLossCorrente<mm_lenta_Buffer[2])
                              STL = NormalizeDouble(MathRound((mm_lenta_Buffer[2])/ticSize)*ticSize,_Digits);
                           if(nivelTStop == 3 && StopLossCorrente<mm_lenta_Buffer[3])
                              STL = NormalizeDouble(MathRound((mm_lenta_Buffer[3])/ticSize)*ticSize,_Digits);
                           if(nivelTStop == 0 && StopLossCorrente<mm_lenta_Buffer[0])
                              STL = NormalizeDouble(MathRound((mm_lenta_Buffer[0])/ticSize)*ticSize,_Digits);
                          }
                        else
                           if(TipoTrail == 0 && (!lateraltrade || tendencia != 0) && precoBid+stopLossMax>rates[1].close)
                             {
                              if(rates[1].open > rates[1].close)
                                {
                                 if(rates[3].high > rates[2].high && rates[2].high > rates[1].high && nivelTStop > 2)
                                    STL = NormalizeDouble(rates[3].high, _Digits);
                                 else
                                    if((rates[2].high > rates[1].high) && (nivelTStop > 1))
                                       STL = NormalizeDouble(rates[2].high, _Digits);
                                    else
                                       if(nivelTStop>0)
                                          STL = NormalizeDouble(rates[1].high, _Digits);
                                       else
                                          STL = NormalizeDouble((rates[0].high+stepTS), _Digits);
                                 STL = NormalizeDouble(MathCeil((STL)/ticSize)*ticSize,_Digits);
                                }
                              else
                                {
                                 if(debug>2 && NovaVela)
                                    Print("Vela Positiva, nada a fazer!");
                                }
                             }
               if(TipoTrail == 1 || STL <= precoBid)
                  STL = NormalizeDouble(PRC+stepTS,_Digits);
               if(STL <= StopLossCorrente-ticSize && STL != 0)
                 {
                  if(d_trade.PositionModify(PositionTicket, STL, TPC) && debug>1)
                     Print("TrailingStop - ** OK **. ResultRetcode: ", d_trade.ResultRetcode(), ", RetcodeDescription: ", d_trade.ResultRetcodeDescription());
                  else
                     if(debug>1 && NovaVela)
                       {
                        Print("TrailingStop - com falha. ResultRetcode: ", d_trade.ResultRetcode(), ", RetcodeDescription: ", d_trade.ResultRetcodeDescription());
                        if(debug>2)
                           Print("Stoploss atual: ", StopLossCorrente, " Stoploss pretendido: ", STL, " Preço atual: ", PRC);
                       }
                 }
               else
                  if(debug>2 && NovaVela)
                     Print("Trailing RECUSADO! Novo stop pior que stop atual!");
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                         PREÇO MÉDIO                              |
//+------------------------------------------------------------------+
void Medio(bool NovaVela, bool pavioBom, bool propBoa)
  {
   if(debug>3)
      Print("Função de Preço Médio chamada!");
   double   precoAbertura;       //Usada na função de Preço Médio
   double   valorAtual;          //Usada na função de Preço Médio
   string   positionComment;     //Usada na função de Preço Médio
   double   volumeAtual;         //Usada na função de Preço Médio
//double   STL = STL;          //Novo StopLoss
//Verifica informações da posição aberta
   PositionSelect(_Symbol);
   for(int i = PositionsTotal()-1; i<=lote*precoMedio; i--)
     {
      string symbol = PositionGetSymbol(i);
      ulong magic = PositionGetInteger(POSITION_MAGIC);
      if(symbol == _Symbol && magic == magicNum)
        {
         ulong PositionTicket = PositionGetInteger(POSITION_TICKET);
         positionComment = PositionGetString(POSITION_COMMENT);
         volumeAtual = PositionGetDouble(POSITION_VOLUME);
         d_profit = PositionGetDouble(POSITION_PROFIT);
         valorAtual = PositionGetDouble(POSITION_PRICE_CURRENT);
         precoAbertura = PositionGetDouble(POSITION_PRICE_OPEN);
         double STL = NormalizeDouble(PositionGetDouble(POSITION_SL), _Digits);
         double TKP = NormalizeDouble(PositionGetDouble(POSITION_TP), _Digits);
         StringAdd(positionComment, " *");
         double lotePM = lotemin;
         if(!lotemedio && tendencia != 0)
            lotePM = lote;
         //Realiza compra para preço médio de acordo com os critérios estabelecidos e posição aberta
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY &&
            ((rates[1].open < rates[1].close && pavioBom && propBoa && d_profit < -limiteMedio*volumeAtual)))
           {
            double PRC = NormalizeDouble(tick.ask, _Digits);
            if(Esp_Stop == 1)
              {
               STL = NormalizeDouble(MathRound((rates[1].close-atr_Buffer[1])/ticSize)*ticSize,_Digits);
               if(debug>2)
                  Print("Stop Loss do Preço Médio ajustado por ATR!");
              }
            else
               if(ajusteStopPM==1 || (ajusteStopPM==2 && volumeAtual+lotePM>=lote*2) || (ajusteStopPM==3 && volumeAtual+lotePM>=lote*precoMedio) || (ajusteStopPM==4 && volumeAtual>=lote*precoMedio))
                 {
                  if(rates[3].low < rates[2].low && rates[2].low < rates[1].low)
                     STL = NormalizeDouble(rates[3].low, _Digits);
                  else
                     if((rates[2].low < rates[1].low))
                        STL = NormalizeDouble(rates[2].low, _Digits);
                     else
                        STL = NormalizeDouble(rates[1].low, _Digits);
                 }
            if(STL < PRC - stopLossMax)
               STL = NormalizeDouble(PRC - stopLossMax, _Digits);
            if(STL > PRC - stopLossMin)
               STL = NormalizeDouble(PRC - stopLossMin, _Digits);
            if(STL < STL)
               STL = STL;
            if(volumeAtual<lote*precoMedio && precoMedio>1)
              {
               if(d_trade.Buy(lotePM, _Symbol, PRC, STL, TKP, positionComment) && debug>1)
                  Print("$ Ordem de Compra fazendo Preço Médio - ** OK **. ResultRetcode: ", d_trade.ResultRetcode(), ", RetcodeDescription: ", d_trade.ResultRetcodeDescription());
               else
                  if(debug>1)
                     Print("Ordem de Compra fazendo Preço Médio - * FALHOU *. ResultRetcode: ", d_trade.ResultRetcode(), ", RetcodeDescription: ", d_trade.ResultRetcodeDescription());
               if(debug>2)
                  Print("Variáveis da função PM: Valor: ", PRC, " Stop atual: ", STL, "Novo Stop: ", STL, " TakeProfit atual: ", TKP, " Quantidade atual: ", volumeAtual);

              }
            if(volumeAtual>=lote*precoMedio)
              {
               if(d_trade.PositionModify(PositionTicket, STL, TKP) && debug>1)
                  Print("Máximo de posições atingido! Ajuste de Stop Preço Médio - ** OK **. ResultRetcode: ", d_trade.ResultRetcode(), ", RetcodeDescription: ", d_trade.ResultRetcodeDescription());
              }
            if(precoMedio==1)
              {
               if(d_trade.PositionModify(PositionTicket, STL, TKP) && debug>1)
                  Print("Ajuste de Stop SEM fazer Preço Médio - ** OK **. ResultRetcode: ", d_trade.ResultRetcode(), ", RetcodeDescription: ", d_trade.ResultRetcodeDescription());
              }
           }
         else
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && symbol == _Symbol && magic==magicNum)
               if(debug>1 && (!pavioBom || !propBoa))
                  Print("# Preço Médio de COMPRA recusado! Vela Ruim!");
               else
                  if(debug>1 && d_profit > -limiteMedio*volumeAtual)
                     Print("# Preço Médio de COMPRA recusado! Prejuízo abaixo do mínimo: R$", d_profit);
                  else
                     if(debug>1 && volumeAtual >= lote*precoMedio && precoMedio != 1)
                        Print("# Preço Médio de COMPRA recusado! Acima da quantidade permitida: ", volumeAtual);
         //Realiza venda para preço médio de acordo com os criérios estabelecidos e posição aberta
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL &&
            ((rates[1].open > rates[1].close && pavioBom && propBoa && d_profit < -limiteMedio*volumeAtual)))
           {
            double PRC = NormalizeDouble(tick.bid, _Digits);
            if(Esp_Stop == 1)
              {
               STL = NormalizeDouble(MathRound((rates[1].close+atr_Buffer[1])/ticSize)*ticSize,_Digits);
               if(debug>2)
                  Print("Stop Loss do Preço Médio ajustado por ATR!");
              }
            else
               if(ajusteStopPM==1 || (ajusteStopPM==2 && volumeAtual+lotePM>=lote*2) || (ajusteStopPM==3 && volumeAtual+lotePM>=lote*precoMedio) || (ajusteStopPM==4 && volumeAtual>=lote*precoMedio))
                 {
                  if(rates[3].high > rates[2].high && rates[2].high > rates[1].high)
                     STL = NormalizeDouble(rates[3].high, _Digits);
                  else
                     if((rates[2].high > rates[1].high))
                        STL = NormalizeDouble(rates[2].high, _Digits);
                     else
                        STL = NormalizeDouble(rates[1].high, _Digits);
                 }
            if(STL > PRC + stopLossMax)
               STL = NormalizeDouble(PRC + stopLossMax, _Digits);
            if(STL < PRC + stopLossMin)
               STL = NormalizeDouble(PRC + stopLossMin, _Digits);
            if(STL > STL)
               STL = STL;
            if(volumeAtual<lote*precoMedio && precoMedio>1)
              {
               if(d_trade.Sell(lotePM, _Symbol, PRC, STL, TKP, positionComment) && debug>1)
                  Print("$ Ordem de Venda fazendo Preço Médio - ** OK **. ResultRetcode: ", d_trade.ResultRetcode(), ", RetcodeDescription: ", d_trade.ResultRetcodeDescription());
               else
                  if(debug>1)
                     Print("Ordem de Venda fazendo Preço Médio - * FALHOU *. ResultRetcode: ", d_trade.ResultRetcode(), ", RetcodeDescription: ", d_trade.ResultRetcodeDescription());
               if(debug>2)
                  Print("Variaveis da função PM: Valor: ", PRC, " Stop atual: ", STL, "Novo Stop: ", STL, " TakeProfit atual: ", TKP, " Quantidade atual: ", volumeAtual);
              }
            if(volumeAtual>=lote*precoMedio)
              {
               if(d_trade.PositionModify(PositionTicket, STL, TKP) && debug>1)
                  Print("Máximo de posições atingido! Ajuste de Stop Preço Médio - ** OK **. ResultRetcode: ", d_trade.ResultRetcode(), ", RetcodeDescription: ", d_trade.ResultRetcodeDescription());
              }
            if(precoMedio==1)
              {
               if(d_trade.PositionModify(PositionTicket, STL, TKP) && debug>1)
                  Print("Ajuste de Stop SEM fazer Preço Médio - ** OK **. ResultRetcode: ", d_trade.ResultRetcode(), ", RetcodeDescription: ", d_trade.ResultRetcodeDescription());
              }
           }
         else
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && symbol == _Symbol && magic==magicNum)
               if(debug>1 && (!pavioBom || !propBoa))
                  Print("# Preço Médio de VENDA recusado! Vela Ruim!");
               else
                  if(debug>1 && d_profit > -limiteMedio*volumeAtual)
                     Print("# Preço Médio de VENDA recusado! Prejuízo abaixo do mínimo: R$", d_profit);
                  else
                     if(debug>1 && volumeAtual >= lote*precoMedio && precoMedio >1)
                        Print("# Preço Médio de VENDA recusado! Acima da quantidade permitida: ", volumeAtual);
         if(debug>2)
            Print("Quantidade atual: ", volumeAtual, " Preço atual: ", valorAtual, " Preço de abertura: ", precoAbertura, " L/P: R$", d_profit);
         break;
        }
     }
  }

//+------------------------------------------------------------------+
//|                       VERIFICA STOPLOSS                          |
//+------------------------------------------------------------------+
void StopCheck()
  {
   if(debug>3)
      Print("Função para verificar StopLoss chamada!");
   for(int i = PositionsTotal()-1; i>=0; i--)
     {
      string symbol = PositionGetSymbol(i);
      ulong magic = PositionGetInteger(POSITION_MAGIC);
      if(symbol == _Symbol && magic == magicNum)
        {
         ulong PositionTicket = PositionGetInteger(POSITION_TICKET);
         double precoAbertura = PositionGetDouble(POSITION_PRICE_OPEN);
         double STL = PositionGetDouble(POSITION_SL);
         double TKP = PositionGetDouble(POSITION_TP);
         bool StopPosicao = PositionGetDouble(POSITION_SL);
         if(posAberta && !StopPosicao)
           {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && tick.bid < precoAbertura)
              {
               double PRC = NormalizeDouble(tick.bid, _Digits);
               STL = NormalizeDouble(PRC-stopLossMin*2,_Digits);
              }
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && tick.ask > precoAbertura)
              {
               double PRC = NormalizeDouble(tick.ask, _Digits);
               STL = NormalizeDouble(PRC+stopLossMin*2,_Digits);
              }
            else
               if(d_trade.PositionModify(PositionTicket, STL, TKP) && debug>1)
                 {
                  Print("Ordem sem Stop detectada. Atribuido último valor conhecido!");
                  if(debug>2)
                     Print("PositionTicket: ", PositionTicket, " Stoploss atribuido: ", STL, " Take Profit atribuido: ", TKP);
                 }
            break;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                  METAS DE GANHOS OU PERDAS                       |
//+------------------------------------------------------------------+
bool metaOuPerda()
  {
   if(debug>3)
      Print("Função para verificar meta ou perda chamada!");
   string         tmp_x;
   double         resultado_financeiro_dia;
   double         maximo_ganho_dia;
   double         maxima_perda_dia;
   int            tmp_contador;
   MqlDateTime    tmp_data_b;
   TimeCurrent(tmp_data_b);
   resultado_financeiro_dia = 0;
   maximo_ganho_dia = 0;
   maxima_perda_dia = 0;
   tmp_x = string(tmp_data_b.year) + "." + string(tmp_data_b.mon) + "." + string(tmp_data_b.day) + " 00:00:01";
   HistorySelect(StringToTime(tmp_x),TimeCurrent());
   int      tmp_total=HistoryDealsTotal();
   ulong    tmp_ticket=0;
   double   tmp_price;
   double   tmp_profit;
   datetime tmp_time;
   string   tmp_symboll;
   long     tmp_typee;
   long     tmp_entry;
//--- para todos os negócios
   for(tmp_contador=0; tmp_contador<tmp_total; tmp_contador++)
     {
      //--- tentar obter ticket negócios
      if((tmp_ticket=HistoryDealGetTicket(tmp_contador))>0)
        {
         //--- obter as propriedades negócios
         tmp_price =HistoryDealGetDouble(tmp_ticket,DEAL_PRICE);
         tmp_time  =(datetime)HistoryDealGetInteger(tmp_ticket,DEAL_TIME);
         tmp_symboll=HistoryDealGetString(tmp_ticket,DEAL_SYMBOL);
         tmp_typee  =HistoryDealGetInteger(tmp_ticket,DEAL_TYPE);
         tmp_entry =HistoryDealGetInteger(tmp_ticket,DEAL_ENTRY);
         tmp_profit=HistoryDealGetDouble(tmp_ticket,DEAL_PROFIT);
         //--- apenas para o símbolo atual
         if(tmp_symboll==Symbol())
            resultado_financeiro_dia = resultado_financeiro_dia + tmp_profit;
         if(resultado_financeiro_dia > maximo_ganho_dia)
            maximo_ganho_dia = resultado_financeiro_dia;
         if(resultado_financeiro_dia < maxima_perda_dia)
            maxima_perda_dia = resultado_financeiro_dia;
        }
     }
   if(resultado_financeiro_dia == 0)
     {
      if(mostraResultado)
         Comment("Resultado R$0.00");
      return(false); //sem ordens no dia
     }
   else
     {
      if(resultado_financeiro_dia > 0 && mostraResultado)
        {
         Comment("Lucro R$" + DoubleToString(NormalizeDouble(resultado_financeiro_dia, 2),2));
         if(debug>1)
            Print("Lucro de R$" + DoubleToString(NormalizeDouble(resultado_financeiro_dia, 2),2), " em ", d_symbol.Name(), " / Meta de lucro: R$", DoubleToString(valorMaximoGanho,2),
                  " / Maior lucro no dia: R$", DoubleToString(maximo_ganho_dia,2), " / Maior perda no dia: R$", DoubleToString(maxima_perda_dia,2));
        }
      if(resultado_financeiro_dia < 0 && mostraResultado)
        {
         Comment("Prejuizo R$" + DoubleToString(NormalizeDouble(resultado_financeiro_dia, 2),2));
         if(debug>1)
            Print("Prejuizo de R$" + DoubleToString(NormalizeDouble(resultado_financeiro_dia, 2),2), " em ", d_symbol.Name(), " / Limite de perda: R$", DoubleToString(valorMaximoPerda,2),
                  " / Maior lucro no dia: R$", DoubleToString(maximo_ganho_dia,2), " / Maior perda no dia: R$", DoubleToString(maxima_perda_dia,2));
        }

      if(resultado_financeiro_dia < -valorMaximoPerda && valorMaximoPerda != 0)
        {
         if(debug>0)
            Print("Perda máxima alcançada: R$", resultado_financeiro_dia, " de R$", DoubleToString(-valorMaximoPerda,2));
         return(true);
        }
      if(resultado_financeiro_dia > valorMaximoGanho && valorMaximoGanho != 0)
        {
         if(debug>0)
            Print("Meta Batida: R$", resultado_financeiro_dia, " de R$", DoubleToString(valorMaximoGanho,2));
         return(true);
        }
      if(((maximo_ganho_dia > valorMaximoGanho*0.75 && resultado_financeiro_dia < maximo_ganho_dia*0.5 && resultado_financeiro_dia > valorMaximoGanho*0.5) || // Fez 3/4 da meta, perdeu metade do lucro, meta reduzida a metade.
          (maximo_ganho_dia > valorMaximoGanho*0.5 && resultado_financeiro_dia < maximo_ganho_dia*0.75 && resultado_financeiro_dia > valorMaximoGanho*0.25)) && valorMaximoGanho != 0) // Fez metade da meta, perdeu 3/4 do lucro, meta reduzida a 1/4.
        {
         Print("Perda do lucro acima do permitido!");
         Print("Para continuar operando, aumente ou desabilite a meta de lucro!");
         return(true);
        }
      if(((maxima_perda_dia < valorMaximoPerda*-0.5 && resultado_financeiro_dia > valorMaximoGanho*0.5) || (maxima_perda_dia < valorMaximoPerda*-0.75 && resultado_financeiro_dia > valorMaximoGanho*0.25)) && valorMaximoPerda != 0) // Reduz meta de lucro caso tenha tido perda significativa
        {
         Print("Recuperação de perda significativa! Metas de lucro reduzidas!");
         Print("Para continuar operando, aumente ou desabilite o limite de perda!");
         return(true);
        }
      if(saiGanhando && valorMaximoGanho != 0)
        {
         datetime op1 = StringToTime("01:00");
         datetime op2 = StringToTime("02:00");
         datetime op3 = StringToTime("03:00");
         datetime op4 = StringToTime("04:00");
         datetime limite = StringToTime(hora_limite_abre_op);
         string agora = TimeToString(TimeCurrent(), TIME_MINUTES);
         string ganha1f;
         string ganha2f;
         string ganha3f;
         string ganha4f;
         datetime ganha1 = limite - op1;
         ganha1f = TimeToString(ganha1, TIME_MINUTES);
         datetime ganha2 = limite - op2;
         ganha2f = TimeToString(ganha2, TIME_MINUTES);
         datetime ganha3 = limite - op3;
         ganha3f = TimeToString(ganha3, TIME_MINUTES);
         datetime ganha4 = limite - op4;
         ganha4f = TimeToString(ganha4, TIME_MINUTES);
         if(debug>4)
           {
            Print(" A partir de ", ganha1f, " redução para 1/5 da meta de lucro. Nova meta R$", valorMaximoGanho/5);
            Print(" A partir de ", ganha2f, " redução para 2/5 da meta de lucro. Nova meta R$", valorMaximoGanho*2/5);
            Print(" A partir de ", ganha3f, " redução para 3/5 da meta de lucro. Nova meta R$", valorMaximoGanho*3/5);
            Print(" A partir de ", ganha4f, " redução para 4/5 da meta de lucro. Nova meta R$", valorMaximoGanho*4/5);
           }
         if(agora>ganha1f && resultado_financeiro_dia > valorMaximoGanho/5)
           {
            Print("Falta menos de 1 hora de negociação, meta de lucro reduzida a 1/5: R$ ", valorMaximoGanho/5);
            return(true);
           }
         else
            if(agora>ganha2f && resultado_financeiro_dia > valorMaximoGanho*2/5)
              {
               Print("Faltam menos de 2 horas de negociação, meta de lucro reduzida a 2/5: R$ ", valorMaximoGanho*2/5);
               return(true);
              }
            else
               if(agora>ganha3f && resultado_financeiro_dia > valorMaximoGanho*3/5)
                 {
                  Print("Faltam menos de 3 horas de negociação, meta de lucro reduzida a 3/5: R$ ", valorMaximoGanho*3/5);
                  return(true);
                 }
               else
                  if(agora>ganha4f && resultado_financeiro_dia > valorMaximoGanho*4/5)
                    {
                     Print("Faltam menos de 4 horas de negociação, meta de lucro reduzida a 4/5: R$ ", valorMaximoGanho*4/5);
                     return(true);
                    }
        }
     }
   return(false);
  }

//+------------------------------------------------------------------+
//|          FUNÇÃO PARA VERIFICAR HORÁRIOS DE NEGOCIAÇÃO            |
//+------------------------------------------------------------------+
bool TimetoTrade()
  {
   if(debug>3)
      Print("Função para verificar horário de negociação chamada!");
   if((TimeToString(TimeCurrent(),TIME_MINUTES) > inicio_operacoes || inicio_operacoes == "00:00") && (TimeToString(TimeCurrent(),TIME_MINUTES) < hora_limite_abre_op || hora_limite_abre_op == "00:00") &&
      (TimeToString(TimeCurrent(),TIME_MINUTES) < inicio_itervalo_1 || TimeToString(TimeCurrent(),TIME_MINUTES) > fim_intervalo_1 || (inicio_itervalo_1 == "00:00" && fim_intervalo_1 == "00:00")) &&
      (TimeToString(TimeCurrent(),TIME_MINUTES) < inicio_itervalo_2 || TimeToString(TimeCurrent(),TIME_MINUTES) > fim_intervalo_2 || (inicio_itervalo_2 == "00:00" && fim_intervalo_2 == "00:00")) && !tradehorarestrita)
      return(true);
   else
      if((TimeToString(TimeCurrent(),TIME_MINUTES) < hora_limite_abre_op || hora_limite_abre_op == "00:00") && tradehorarestrita)
         return(true);
      else
         return(false);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool restricao()
  {
   if(((TimeToString(TimeCurrent(),TIME_MINUTES) < inicio_operacoes) ||
       (TimeToString(TimeCurrent(),TIME_MINUTES) > inicio_itervalo_1 && TimeToString(TimeCurrent(),TIME_MINUTES) < fim_intervalo_1) ||
       (TimeToString(TimeCurrent(),TIME_MINUTES) > inicio_itervalo_2 && TimeToString(TimeCurrent(),TIME_MINUTES) < fim_intervalo_2)) && tradehorarestrita)
      return(true);
   else
      if((rates[1].close < mm_principal_Buffer[1] && rates[1].close > rates[1].open) || (rates[1].close > mm_principal_Buffer[1] && rates[1].close < rates[1].open))
         return(true);
      else
         return(false);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int ToposeFundos()
  {
//Fitro de Topos e Fundos
   if((rates[1].close > Topo1 - rangeLateral && rates[1].close < Topo1 + rangeLateral) || (rates[1].close > Fundo1 - rangeLateral && rates[1].close < Fundo1 + rangeLateral) ||
      (rates[1].close > Topo2 - rangeLateral && rates[1].close < Topo2 + rangeLateral) || (rates[1].close > Fundo2 - rangeLateral && rates[1].close < Fundo2 + rangeLateral) ||
      (rates[1].close > Topo3 - rangeLateral && rates[1].close < Topo3 + rangeLateral) || (rates[1].close > Fundo3 - rangeLateral && rates[1].close < Fundo3 + rangeLateral))
      FiltroTouF = true;
   else
      FiltroTouF = false;

   if(rates[1].high>rates[3].high && rates[2].high>rates[3].high && rates[1].low>rates[2].low && rates[2].low>rates[3].low && rates[3].low<rates[4].low && rates[3].low<rates[5].low && (TouF || Fundo1 > rates[3].low) &&
      (((rates[3].close > Topo1 - rangeLateral && rates[3].close < Topo1 + rangeLateral) || (rates[3].close > Fundo1 - rangeLateral && rates[3].close < Fundo1 + rangeLateral) ||
        (rates[3].close > Topo2 - rangeLateral && rates[3].close < Topo2 + rangeLateral) || (rates[3].close > Fundo2 - rangeLateral && rates[3].close < Fundo2 + rangeLateral) ||
        (rates[3].close > Topo3 - rangeLateral && rates[3].close < Topo3 + rangeLateral) || (rates[3].close > Fundo3 - rangeLateral && rates[3].close < Fundo3 + rangeLateral)))==false)
     {
      if(TouF)
        {
         Fundo3 = Fundo2;
         Fundo2 = Fundo1;
        }
      Fundo1 = rates[3].low;
      TouF = false;
      UltimoFundo = TimeToString(TimeCurrent(),TIME_MINUTES);
      return(1); //Máximos e mínimos ascendentes - Novo Fundo
     }
   else
      if(rates[1].high<rates[2].high && rates[2].high<rates[3].high && rates[3].high>rates[4].high && rates[3].high>rates[5].high && rates[1].low<rates[3].low && rates[2].low<rates[3].low && (!TouF || Topo1 < rates[3].high) &&
         (((rates[3].close > Topo1 - rangeLateral && rates[3].close < Topo1 + rangeLateral) || (rates[3].close > Fundo1 - rangeLateral && rates[3].close < Fundo1 + rangeLateral) ||
           (rates[3].close > Topo2 - rangeLateral && rates[3].close < Topo2 + rangeLateral) || (rates[3].close > Fundo2 - rangeLateral && rates[3].close < Fundo2 + rangeLateral) ||
           (rates[3].close > Topo3 - rangeLateral && rates[3].close < Topo3 + rangeLateral) || (rates[3].close > Fundo3 - rangeLateral && rates[3].close < Fundo3 + rangeLateral)))==false)
        {
         if(!TouF)
           {
            Topo3 = Topo2;
            Topo2 = Topo1;
           }
         Topo1 = rates[3].high;
         TouF = true;
         UltimoTopo = TimeToString(TimeCurrent(),TIME_MINUTES);
         return(2); //Máximos e mínimos descendentes - Novo Topo
        }
      else
         if(rates[1].high>rates[2].high && rates[2].high>rates[3].high && rates[3].high>rates[4].high && rates[4].high>rates[5].high && rates[1].low<rates[2].low && rates[2].low<rates[3].low && rates[3].low<rates[4].low && rates[4].low<rates[5].low)
            return(3); //Alargamento
         else
           {
            if(rates[1].low>rates[5].low && rates[2].low>rates[5].low && rates[3].low>rates[5].low && rates[4].low>rates[5].low)
               TouF = false;
            if(rates[1].high<rates[5].high && rates[2].high<rates[5].high && rates[3].high<rates[5].high && rates[4].high<rates[5].high)
               TouF = true;
            return(0);
           }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int Tendencia()
  {
//Retorna 0 para Lateralidade, 1 para resistencia, 2 para tendencia de alta, 3 para tendencia de baixa
// LÓGICA PARA FILTRO DE LATERALIDADE E RESISTÊNCIA
   bool filtro_lateral = ((((mm_rapida_Buffer[1]<rates[1].high && rates[1].high-mm_rapida_Buffer[1]<rangeLateral*2) ||// O máximo da última vela não dista mais que 2x o valor de limite da lateralidade da média rápida
                            (mm_rapida_Buffer[1]>rates[1].low && mm_rapida_Buffer[1]-rates[1].low<rangeLateral*2)) && // O mímimo da última vela não dista mais que 2x o valor de limite da lateralidade da média rápida
                           ((mm_lenta_Buffer[1]<rates[1].close && rates[1].close-mm_lenta_Buffer[1]<rangeLateral*2) ||
                            (mm_lenta_Buffer[1]>rates[1].close && mm_lenta_Buffer[1]-rates[1].close<rangeLateral*2))) &&// O fechamento da última vela não dista mais que 2x o valor de limite da lateralidade da média lenta
                          ((rates[1].close>rates[2].open && rates[1].close-rates[2].open<rangeLateral*2.5) || (rates[1].close<rates[2].open && rates[2].open-rates[1].close<rangeLateral*2.5) || // O fechamento do candle1 é maior que a abertura do candle2, mas a diferença entres eles é menor que o triplo do limite de lateralidade
                           (rates[1].close>mm_lenta_Buffer[1] && rates[1].close<mm_lenta_Buffer[1]+rangeLateral*2) || (rates[1].close<mm_lenta_Buffer[1] && rates[1].close>mm_lenta_Buffer[1]-rangeLateral*2)) && // Se o fechamento do candle1 for perto da média lenta, invalida o descumprimento da regra anterior
                          ((mm_rapida_Buffer[1]<mm_lenta_Buffer[1] && mm_rapida_Buffer[1]>mm_lenta_Buffer[1]-rangeLateral) ||     // Media rapida atual < lenta atual e rapida atual > lenta menos o range de lateralidade ou \ Media rapida menor que lenta, mas não tao menor ou
                           (mm_rapida_Buffer[1]>mm_lenta_Buffer[1] && mm_rapida_Buffer[1]<mm_lenta_Buffer[1]+rangeLateral)) &&    // Media rapida atual > lenta atual e rapida atual < lenta mais o range de lateralidade    / media rapida maior que a lenta, mas não tão maior
                          ((mm_rapida_Buffer[3]<mm_lenta_Buffer[3] && mm_rapida_Buffer[3]>mm_lenta_Buffer[3]-rangeLateral*1.3) || // Repete logica para periodos anteriores
                           (mm_rapida_Buffer[3]>mm_lenta_Buffer[3] && mm_rapida_Buffer[3]<mm_lenta_Buffer[3]+rangeLateral*1.3)) &&
                          ((mm_rapida_Buffer[5]<mm_lenta_Buffer[5] && mm_rapida_Buffer[5]>mm_lenta_Buffer[5]-rangeLateral*1.5) || // Repete logica para periodos anteriores
                           (mm_rapida_Buffer[5]>mm_lenta_Buffer[5] && mm_rapida_Buffer[5]<mm_lenta_Buffer[5]+rangeLateral*1.5)) &&
                          ((mm_rapida_Buffer[7]<mm_lenta_Buffer[7] && mm_rapida_Buffer[7]>mm_lenta_Buffer[7]-rangeLateral*1.7) ||
                           (mm_rapida_Buffer[7]>mm_lenta_Buffer[7] && mm_rapida_Buffer[7]<mm_lenta_Buffer[7]+rangeLateral*1.7)) &&
                          ((mm_rapida_Buffer[9]<mm_lenta_Buffer[9] && mm_rapida_Buffer[9]>mm_lenta_Buffer[9]-rangeLateral*1.9) || // Repete logica para periodos anteriores
                           (mm_rapida_Buffer[9]>mm_lenta_Buffer[9] && mm_rapida_Buffer[9]<mm_lenta_Buffer[9]+rangeLateral*1.9))) &&
                         ((rates[1].close>rates[1].open && (rates[1].low < mm_rapida_Buffer[1] || rates[2].low < mm_rapida_Buffer[2] || rates[3].low < mm_rapida_Buffer[3])) || // Um dos três candles mais recentes tem que ter tocado a média rápida.
                          (rates[1].close<rates[1].open && (rates[1].high > mm_rapida_Buffer[1] || rates[2].high > mm_rapida_Buffer[2] || rates[3].high > mm_rapida_Buffer[3])));
// LÓGICA PARA FILTRO DE RESISTÊNCIA
   bool resistencia = (((rates[1].close>mm_principal_Buffer[1]&&rates[1].close<mm_principal_Buffer[1]+rangeLateral) ||
                        (rates[1].close<mm_principal_Buffer[1]&&rates[1].close>mm_principal_Buffer[1]-rangeLateral)) &&
                       ((rates[2].close>mm_principal_Buffer[2]&&rates[2].close<mm_principal_Buffer[2]+rangeLateral*2) ||
                        (rates[2].close<mm_principal_Buffer[2]&&rates[2].close>mm_principal_Buffer[2]-rangeLateral*2)) &&
                       ((mm_rapida_Buffer[1]>mm_principal_Buffer[1] && mm_rapida_Buffer[1]-mm_principal_Buffer[1]<rangeLateral)||
                        (mm_rapida_Buffer[1]<mm_principal_Buffer[1] && mm_principal_Buffer[1]-mm_rapida_Buffer[1]<rangeLateral))&& // Média rápida1 fica perto da média principal1
                       ((mm_rapida_Buffer[3]>mm_principal_Buffer[3] && mm_rapida_Buffer[3]-mm_principal_Buffer[3]<rangeLateral*1.5)||
                        (mm_rapida_Buffer[3]<mm_principal_Buffer[3] && mm_principal_Buffer[3]-mm_rapida_Buffer[3]<rangeLateral*1.5))&& // Média rápida3 fica perto da média principal3
                       ((mm_rapida_Buffer[5]>mm_principal_Buffer[5] && mm_rapida_Buffer[5]-mm_principal_Buffer[5]<rangeLateral*2)||
                        (mm_rapida_Buffer[5]<mm_principal_Buffer[5] && mm_principal_Buffer[5]-mm_rapida_Buffer[5]<rangeLateral*2))); // Média rápida5 fica perto da média principal5
   if(filtro_lateral)
      return(0);
   else
      if(resistencia)
         return(1);
      else
         if(rates[1].open > mm_principal_Buffer[1] && rates[1].close > mm_principal_Buffer[1])
            return(2);
         else
            if(rates[1].open < mm_principal_Buffer[1] && rates[1].close < mm_principal_Buffer[1])
               return(3);
            else
               return(4);
  }
//+------------------------------------------------------------------+
