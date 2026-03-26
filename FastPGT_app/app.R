library(shiny)
library(tidyverse)
library(DT)

rm(list = ls())
source("R/simulator.R")



benchmarks <- list(
  FAST = list(
    mean = 83.6,
    p10  = 84.0,
    p90  = 84.7
  ),
  STANDARD = list(
    mean = 60.8,
    p10  = 60.5,
    p90  = 61.2
  )
)

evaluate_cost <- function(cost) {
  
  # FAST
  fast_status <- if (cost > benchmarks$FAST$p90) {
    "🔴 Por encima del rango FAST (ineficiente)"
  } else if (cost < benchmarks$FAST$p10) {
    "🟢 Mejor que FAST"
  } else {
    "🟡 Dentro del rango FAST"
  }
  
  # STANDARD
  standard_status <- if (cost > benchmarks$STANDARD$p90) {
    "🔴 Por encima del rango STANDARD"
  } else if (cost < benchmarks$STANDARD$p10) {
    "🟢 Mejor que STANDARD"
  } else {
    "🟡 Dentro del rango STANDARD"
  }
  
  list(
    fast = fast_status,
    standard = standard_status
  )
}

ui <- fluidPage(
  
  titlePanel("FastPGT Calculator"),
  
  fluidRow(
    
    # 🔹 COLUMNA IZQUIERDA
    column(
      width = 4,
      
      wellPanel(
        h4("Costos de reactivos"),
        
        fluidRow(
          column(6, numericInput("C_FC", "Flow Cell ($)", 1125)),
          column(6, numericInput("C_RBK", "RBK (6x24) ($)", 1300))
        ),
        
        fluidRow(
          column(6, numericInput("C_RAA", "RAA (6x24) ($)", 543)),
          column(6, numericInput("C_WGA", "WGA kit (96) ($)", 1890))
        ),
        
        fluidRow(
          column(6, numericInput("C_wash", "Wash kit (6) ($)", 194))
        )
      ),
      
      wellPanel(
        textInput(
          "runs",
          "Número de muestras por corrida (n_i =  4, 8, 10, 6, ...)",
          value = "5, 5, 8, 8, 10, 10"
        )
      ),
      
      wellPanel(
        h4("Estado operativo"),
      
        
        fluidRow(
          
          column(
            6,
            strong("Barcodes RBK restantes"),
            br(),
            textOutput("rbk_rest")
          ),
          
          column(
            6,
            strong("Reacciones RAA restantes"),
            br(),
            textOutput("raa_rest")
          )
        ),
        
        br(),
        
        fluidRow(
          
          column(
            6,
            strong("Capacidad FC"),
            br(),
            textOutput("fc_rest")
          ),
          
          column(
            6,
            strong("Corridas FC restantes"),
            br(),
            textOutput("runs_rest")
          )
        ),
        br(),
        strong("Estado"),
        textOutput("estado_txt")
      )
    ),
    
    
    # 🔹 COLUMNA DERECHA
    column(
      width = 8,
      
      fluidRow(
        column(2, h4("C_muestra(US$)"), textOutput("kpi_costo")),
        column(2, h4("Flow Cells"), textOutput("kpi_fc")),
        column(2, h4("Corridas"), textOutput("kpi_runs")),
        column(2, h4("Eficiencia"), textOutput("kpi_eficiencia")),
        column(2, h4("Decisión"), textOutput("decision"))
      ),
      
      br(),
      uiOutput("benchmark"),
      br(),
      br(),
 
      h5("Resumen"),
      tableOutput("resumen"),
      
      br(),
      plotOutput("plot")
    )
  ),
  
  # 🔥 FULL WIDTH ABAJO
  fluidRow(
    column(
      12,
      hr(),
      h3("Detalle de corridas (valores en USD)"),
      DTOutput("detalle")
    )
  ),
  plotOutput("plot_costos", height = "400px")
  
)
  

###---------------------------------------------------
### SERVER
###---------------------------------------------------

server <- function(input, output) {
  
  # -----------------------
  # PARSE RUNS
  # -----------------------
  
  runs <- reactive({
    x <- as.numeric(strsplit(input$runs, ",")[[1]])
    x <- x[!is.na(x) & x > 0]
    
    validate(
      need(length(x) > 0, "Debe ingresar al menos una corrida."),
      need(all(x <= 24), "Ninguna corrida puede superar 24 muestras."),
      need(all(x >= 1), "Cada corrida debe ser mayor a 0.")
    )
    
    x
  })
  
  
  # -----------------------
  # PARSE REACTIVOS
  # -----------------------
  
  params <- reactive({
    list(
      C_FC = input$C_FC,
      C_RBK = input$C_RBK,
      C_RAA = input$C_RAA,
      
      # 🔥 convertir a unitario
      C_WGA = input$C_WGA / 100,
      C_wash = input$C_wash / 6
    )
  })
  # -----------------------
  # SIMULACIÓN
  # -----------------------
  
  sim <- reactive({
    req(length(runs()) > 0)
    simulate_runs(runs(), params = params())
  })
  
  
  # -----------------------
  # RESUMEN
  # -----------------------
  
  resumen <- reactive({
    df <- sim()
    
    tibble(
      total_muestras = sum(df$muestras),
      total_corridas = nrow(df),
      flow_cells_usadas = as.integer(max(df$FC_actual)),
      costo_total = round(max(df$costo_acumulado), 2),
      costo_por_muestra = round(max(df$costo_acumulado) / sum(df$muestras), 2)
    )
  })
  
  # -----------------------
  # ESTADO OPERATIVO
  # -----------------------
  
  estado <- reactive({
    
    df <- sim()
    last <- tail(df, 1)
    
    muestras_totales <- last$muestras_totales
    muestras_en_fc <- last$muestras_en_FC
    corridas_totales <- nrow(df)
    
    corrida_en_fc <- ((corridas_totales - 1) %% 6) + 1
    
    list(
      rbk_rest = (144 - (muestras_totales %% 144)) %% 144,
      raa_rest = (6 - (corridas_totales %% 6)) %% 6,
      fc_rest = 48 - muestras_en_fc,
      runs_rest = 6 - corrida_en_fc
    )
  })
  
  # -----------------------
  # KPIs
  # -----------------------
  
  output$kpi_costo <- renderText({
    round(resumen()$costo_por_muestra, 2)
  })
  
  output$kpi_fc <- renderText({
    as.integer(resumen()$flow_cells_usadas)
  })
  
  output$kpi_runs <- renderText({
    resumen()$total_corridas
  })
  
  output$raa_rest <- renderText({
    estado()$raa_rest
  })
  
  
  # -----------------------
  # BENCHMARK INTERPRETACIÓN
  # -----------------------
  
  output$benchmark <- renderUI({
    
    costo <- resumen()$costo_por_muestra
    
    eval <- evaluate_cost(costo)
    
    div(
      style = "padding:10px; border-radius:8px; background:#f5f5f5;",
      
      strong("Benchmark operativo"),
      br(), br(),
      
      span(strong("FAST: "), eval$fast),
      br(),
      span(strong("STANDARD: "), eval$standard)
    )
  })
  
  
  # -----------------------
  # EFICIENCIA
  # -----------------------
  
  output$kpi_eficiencia <- renderText({
    
    costo <- resumen()$costo_por_muestra
    r <- resumen()$total_corridas
    
    baseline <- sapply(2:24, function(x){
      run_simulation(x, r)$resumen$costo_por_muestra
    })
    
    eficiencia <- costo / min(baseline)
    
    paste0("+", round((eficiencia - 1)*100, 1), "% vs óptimo")
  })
  
  # -----------------------
  # DECISIÓN
  # -----------------------
  
  output$decision <- renderText({
    
    costo <- resumen()$costo_por_muestra
    r <- resumen()$total_corridas
    
    baseline <- sapply(2:24, function(x){
      run_simulation(x, r)$resumen$costo_por_muestra
    })
    
    eficiencia <- costo / min(baseline)
    
    case_when(
      eficiencia <= 1.05 ~ "Óptimo",
      eficiencia <= 1.20 ~ "Operación eficiente",
      eficiencia <= 1.40 ~ "Margen de mejora",
      TRUE ~ "Optimización necesaria"
    )
  })
  
  # -----------------------
  # ESTADO OUTPUTS
  # -----------------------
  
  output$rbk_rest <- renderText({
    estado()$rbk_rest
  })
  
  output$fc_rest <- renderText({
    estado()$fc_rest
  })
  
  output$runs_rest <- renderText({
    estado()$runs_rest
  })
  
  output$estado_txt <- renderText({
    
    s <- estado()
    
    if(s$fc_rest < 5){
      "⚠️ FC casi lleno"
    } else if(s$rbk_rest < 10){
      "⚠️ RBK por agotarse"
    } else if(s$raa_rest == 0){
      "⚠️ Reponer RAA"
    } else {
      "✔ Operación estable"
    }
    
  })
  
  # -----------------------
  # RESUMEN TABLA
  # -----------------------
  
  output$resumen <- renderTable({
    resumen()
  })
  
  # -----------------------
  # PLOT
  # -----------------------
  output$plot <- renderPlot({
    
    df <- sim()
    
    if(is.null(df) || nrow(df) == 0){
      return(NULL)
    }
    
    # -----------------------
    # EVENTOS
    # -----------------------
    
    raa_lines <- df %>%
      dplyr::filter(corrida %% 6 == 0)
    
    fc_lines <- df %>%
      dplyr::filter(grepl("Nuevo FC", evento))
    
    rbk_lines <- df %>%
      dplyr::filter(grepl("RBK", evento))
    
    max_corrida <- max(df$corrida, na.rm = TRUE)
    
    ymax <- max(df$costo_promedio_global, na.rm = TRUE)
    
    ggplot(df, aes(x = corrida, y = costo_promedio_global)) +
      
      geom_line(color = "#5F9EA0", size = 1) +
      geom_point(color = "#2F4F4F", size = 2) +
      
      # -----------------------
    # LÍNEAS
    # -----------------------
    
    geom_vline(
      data = raa_lines,
      aes(xintercept = corrida),
      linetype = "dashed",
      color = "#2b203d",
      linewidth = 0.6
    ) +
      
      geom_vline(
        data = fc_lines,
        aes(xintercept = corrida),
        linetype = "dashed",
        color = "#b80c09",
        linewidth = 0.6
      ) +
      
      geom_vline(
        data = rbk_lines,
        aes(xintercept = corrida),
        linetype = "dotted",
        color = "#d4aa7d",
        linewidth = 0.6
      ) +
      
      # -----------------------
    # LABELS
    # -----------------------
    
    geom_text(
      data = fc_lines,
      aes(x = corrida, y = ymax * 1.04, label = "FC"),
      angle = 90,
      vjust = -0.3,
      size = 3,
      color = "#b80c09"
    ) +
      
      geom_text(
        data = rbk_lines,
        aes(x = corrida, y = ymax * 1.11, label = "RBK"),
        angle = 90,
        vjust = -0.3,
        size = 3,
        color = "#d4aa7d"
      ) +
      
      geom_text(
        data = raa_lines,
        aes(x = corrida, y = ymax * 1.20, label = "RAA"),
        angle = 90,
        vjust = -0.3,
        size = 3,
        color = "#2b203d"
      ) +
      
      # -----------------------
    # ESCALAS
    # -----------------------
    
    scale_x_continuous(
      breaks = seq(1, max_corrida, 1),
      minor_breaks = seq(1, max_corrida, 0.5)
    ) +
      
      scale_y_continuous(
        limits = c(0, ymax * 1.2),   # 👈 espacio para labels
        minor_breaks = scales::pretty_breaks(n = 20)
      ) +
      
      labs(
        title = "Evolución del costo por muestra",
        x = "Corrida",
        y = "USD / muestra"
      ) +
      
      theme_minimal() +
      
      theme(
        panel.grid.major = element_line(color = "#CADFE3", size = 0.4),
        panel.grid.minor = element_line(color = "#E8F3F5", size = 0.2)
      )
  })
  
  # -----------------------
  # DETALLE
  # -----------------------
  
  
  output$detalle <- DT::renderDataTable({
    
    df <- sim() %>%
      dplyr::mutate(
        corrida = as.numeric(corrida),
        muestras = as.numeric(muestras),
        FC_actual = as.numeric(FC_actual),
        evento_color = dplyr::case_when(
          stringr::str_detect(evento, "RBK")      ~ "#FFF68F",
          stringr::str_detect(evento, "RAA")      ~ "#B4EEB4",
          stringr::str_detect(evento, "Nuevo FC") ~ "#FF6A6A",
          stringr::str_detect(evento, "Wash")     ~ "#97FFFF",
          TRUE                                    ~ "#FFFFFF"
        )
      ) %>%
      dplyr::arrange(dplyr::desc(corrida)) %>%
      dplyr::select(
        corrida,
        muestras,
        costo_WGA,
        costo_RBK,
        costo_RAA,
        costo_FC,
        costo_wash,
        costo_run_modelado,
        muestras_totales,
        RBK_id,
        run_in_rbk_counter,
        raa_counter,
        muestras_en_FC,
        FC_actual,
        evento,
        evento_color,
        costo_acumulado,
        costo_promedio_global
      ) %>%
      dplyr::rename(
        "Corrida" = corrida,
        "Muestras" = muestras,
        "Costo WGA" = costo_WGA,
        "Costo RBK" = costo_RBK,
        "Costo RAA" = costo_RAA,
        "Costo Flow Cell" = costo_FC,
        "Costo Wash" = costo_wash,
        "Costo Corrida" = costo_run_modelado,
        "Muestras Totales" = muestras_totales,
        "RBK #" = RBK_id,
        "Corrida en kit RBK" = run_in_rbk_counter,
        "Corrida en kit RAA" = raa_counter,
        "Muestras en FC" = muestras_en_FC,
        "Flow Cell #" = FC_actual,
        "Evento" = evento,
        "Color" = evento_color,
        "Costo Acumulado" = costo_acumulado,
        "Costo Promedio" = costo_promedio_global
      )
    
    # -----------------------
    # COLUMNAS VISIBLES
    # -----------------------
    
    cols_visibles <- c(
      "Corrida",
      "Muestras",
      "Muestras Totales",
      "Flow Cell #",
      "RBK #",
      "Corrida en kit RBK",
      "Corrida en kit RAA",
      "Evento",
      "Costo Corrida",
      "Costo Promedio",
      "Costo Acumulado",
      "Color"   # necesaria para colorear
    )
    
    df <- df %>% dplyr::select(all_of(cols_visibles))
    
    # -----------------------
    # COLUMNAS NUMÉRICAS (auto)
    # -----------------------
    
    cols_numericas <- intersect(
      c("Costo WGA","Costo RBK","Costo RAA","Costo Flow Cell",
        "Costo Wash","Costo Corrida","Costo Acumulado","Costo Promedio"),
      names(df)
    )
    
    DT::datatable(
      df,
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        order = list(list(0, "desc")),
        columnDefs = list(
          list(visible = FALSE, targets = which(names(df) == "Color") - 1)
        )
      ),
      rownames = FALSE
    ) %>%
      DT::formatRound(
        columns = cols_numericas,
        digits = 2
      ) %>%
      DT::formatStyle(
        "Evento",
        valueColumns = "Color",
        backgroundColor = DT::styleValue(),
        fontWeight = "bold"
      )
  })
  
  
  output$plot_costos <- renderPlot({
    
    df <- sim()
    
    ggplot(df, aes(x = corrida, y = costo_run_modelado)) +
      
      # línea principal
      geom_line(size = 1) +
      
      # puntos
      geom_point(aes(color = evento), size = 3) +
      
      # líneas verticales FC
      geom_vline(
        data = df %>% dplyr::filter(stringr::str_detect(evento, "Nuevo FC")),
        aes(xintercept = corrida),
        linetype = "dashed",
        color = "red",
        alpha = 0.6
      ) +
      
      # líneas verticales RBK
      geom_vline(
        data = df %>% dplyr::filter(stringr::str_detect(evento, "RBK")),
        aes(xintercept = corrida),
        linetype = "dotted",
        color = "goldenrod",
        alpha = 0.7
      ) +
      
      # líneas verticales RAA (cuando arranca ciclo)
      geom_vline(
        data = df %>% dplyr::filter(raa_counter == 1),
        aes(xintercept = corrida),
        linetype = "dotdash",
        color = "darkgreen",
        alpha = 0.7
      ) +
      
      labs(
        title = "Costo por corrida y eventos operativos",
        x = "Corrida",
        y = "Costo (USD)",
        color = "Evento"
      ) +
      
      theme_minimal() +
      theme(
        plot.title = element_text(size = 16, face = "bold")
      )
  })
  
  
  
}



shinyApp(ui, server)

