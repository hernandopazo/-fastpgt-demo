#++++++++++++++++++++++++++++
# Simulador 22 de marzo de 2026
# Hernan Dopazo
# IEGEBA 2pq
# motor de simulación + API + lógica de decisión
#++++++++++++++++++++++++++++

#print("SIMULADOR NUEVO ACTIVO")

# -----------------------------
# PARÁMETROS
# -----------------------------

params_default <- list(
  C_FC   = 1125.20,
  C_wash = 32.33,
  C_RBK  = 1300,
  C_RAA  = 543,
  C_WGA  = 22.33
)

# ============================================================
# SIMULADOR 
# ============================================================

simulate_runs <- function(runs, params = params_default){
  
  # -----------------------
  # VALIDACIÓN
  # -----------------------
  if(any(runs > 24)){
    stop("Error: ninguna corrida puede superar 24 muestras.")
  }
  
  if(any(runs <= 0)){
    stop("Error: todas las corridas deben ser mayores a 0.")
  }
  
  FC_count <- 1
  RBK_count <- 1
  WGA_count <- 1
  RBK_id <- 1
  
  run_in_fc <- 0
  samples_in_fc <- 0
  total_samples <- 0
  raa_cycle <- 0
  run_in_rbk_counter <- 0
  
  reactions_left <- 6
  
  total_cost <- params$C_FC + params$C_RBK + params$C_RAA
  
  log <- list()
  
  for(i in seq_along(runs)){
    
    n <- runs[i]
    evento <- c()
    
    # -----------------------
    # CAMBIO DE FC (FIX REAL)
    # -----------------------
    while(samples_in_fc + n > 48 || run_in_fc >= 6){
      
      FC_count <- FC_count + 1
      run_in_fc <- 0
      samples_in_fc <- 0
      
      total_cost <- total_cost + params$C_FC
      evento <- c(evento, "Nuevo FC")
    }
    
    # -----------------------
    # WASH
    # -----------------------
    wash_cost <- 0
    if(run_in_fc > 0){
      total_cost <- total_cost + params$C_wash
      wash_cost <- params$C_wash
      evento <- c(evento, "Wash")
    }
    
    # -----------------------
    # RBK
    # -----------------------
    RBK_needed <- ceiling((total_samples + n) / 144)
    
    if(RBK_needed > RBK_count){
      RBK_count <- RBK_needed
      RBK_id <- RBK_id + 1   # 👈 clave
      
      total_cost <- total_cost + params$C_RBK
      evento <- c(evento, "Compra RBK")
    }
    
    # -----------------------
    # WGA
    # -----------------------
    WGA_needed <- ceiling((total_samples + n) / 96)
    
    if(WGA_needed > WGA_count){
      WGA_count <- WGA_needed
      total_cost <- total_cost + params$C_WGA * 96
      evento <- c(evento, "Compra WGA")
    }
    
    total_samples <- total_samples + n
    
    # -----------------------
    # RAA
    # -----------------------

    if(reactions_left == 0){
      reactions_left <- 6
      total_cost <- total_cost + params$C_RAA
      evento <- c(evento, "Compra RAA")
      
      raa_cycle <- raa_cycle + 1   # 👈 CLAVE
    }
    
    reactions_left <- reactions_left - 1
#    print(paste("run:", i, "raa_cycle:", raa_cycle))
    
    
    # -----------------------
    # COSTO MODELO
    # -----------------------
    costo_WGA  <- n * params$C_WGA
    costo_FC   <- n * (params$C_FC / 48)

    samples_in_rbk <- (total_samples - n) %% 144
    
    # -----------------------
    # CONTROL DE RBK 
    # -----------------------
    
    if(i == 1){
      run_in_rbk_counter <- 1
    } else {
      if(RBK_id != prev_RBK_id){
        run_in_rbk_counter <- 1
      } else {
        run_in_rbk_counter <- run_in_rbk_counter + 1
      }
    }
    
    prev_RBK_id <- RBK_id
    # -----------------------
    # COSTO RAA CORRECTO
    # -----------------------
    
    
    raa_counter <- 0
    costo_RAA <- 0
    
    if(run_in_rbk_counter > 6){
      
      # posición dentro del bloque RAA
      raa_counter <- ((run_in_rbk_counter - 7) %% 6) + 1
      
      costo_RAA <- params$C_RAA / 6
    }

    costo_RBK  <- n * (params$C_RBK / 144)
    costo_wash <- wash_cost
    costo_run_modelado <- 
      costo_WGA +
      costo_FC +
      costo_RAA +
      costo_RBK +
      costo_wash
    
    
    # -----------------------
    # UPDATE FC
    # -----------------------
    run_in_fc <- run_in_fc + 1
    samples_in_fc <- samples_in_fc + n
    
    log[[i]] <- tibble::tibble(
      corrida = i,
      muestras = n,
      muestras_totales = total_samples,
      muestras_en_FC = samples_in_fc,
      FC_actual = FC_count,
      evento = ifelse(length(evento) == 0,"Arranca_RBK", paste(evento, collapse = " + ")),
      RBK_id = RBK_id,
      run_in_rbk_counter = run_in_rbk_counter,
      raa_counter = raa_counter,
      raa_cycle_global = raa_cycle,
      # -----------------------
      # COSTOS ABSOLUTOS
      # -----------------------
      
      costo_WGA = costo_WGA,
      costo_FC = costo_FC,
      costo_RAA = costo_RAA,
      costo_RBK = costo_RBK,
      costo_wash = costo_wash,
      
      # COSTOS UNITARIOS
      
      costo_WGA_unit = costo_WGA / n,
      costo_FC_unit  = costo_FC / n,
      costo_RAA_unit = costo_RAA / n,
      costo_RBK_unit = costo_RBK / n,
      costo_wash_unit = costo_wash / n,
      
      # -----------------------
      # TOTALES
      # -----------------------
      
      costo_run_modelado = costo_run_modelado,
      costo_acumulado = total_cost,
      costo_promedio_global = total_cost / total_samples
    )
  }
  
  dplyr::bind_rows(log)
}


# --------------------------------------------------
# API
# --------------------------------------------------

run_simulation <- function(n, r, params = params_default){
  
  runs <- rep(n, r)
  
  res <- simulate_runs(runs, params)
  
  resumen <- res %>%
    dplyr::summarise(
      total_muestras = sum(muestras),
      total_corridas = dplyr::n(),
      flow_cells_usadas = max(FC_actual),
      costo_total = max(costo_acumulado),
      costo_por_muestra = costo_total / total_muestras
    )
  
  list(
    detalle = res,
    resumen = resumen
  )
}

# --------------------------------------------------
# DECISION
# --------------------------------------------------

decision_run <- function(n, r, params = params_default){
  
  sim <- run_simulation(n, r, params)
  costo <- sim$resumen$costo_por_muestra
  
  baseline <- sapply(2:24, function(x){
    run_simulation(x, r, params)$resumen$costo_por_muestra
  })
  
  costo_optimo <- min(baseline)
  
  eficiencia <- costo / costo_optimo
  
  dplyr::case_when(
    eficiencia <= 1.05 ~ "Óptimo",
    eficiencia <= 1.20 ~ "Aceptable",
    TRUE ~ "Ineficiente"
  )
}




