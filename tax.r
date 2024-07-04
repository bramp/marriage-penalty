library(dplyr)
library(knitr)
library(usincometaxes)

results <- read.csv("penalty-simple.csv")
#results <- read.csv("penalty-extra.csv")

generate <- function() {
  # Ages
  page  = 30
  sage  = 30
  
  # Range of wages to graph
  wage_seq = seq(0, 1000000, by=10000)
  
  i <- 0
  results <- vector('list', length(wage_seq) * length(wage_seq))

  # Wages
  for (pwage in wage_seq) {
    for (swage in wage_seq) {
      i <- i + 1
      
      # Simulate two filling seperately, then filling jointly
      # All variables here: https://www.shaneorr.io/r/usincometaxes/articles/taxsim-input
      family_income <- data.frame(
        taxsimid = c(1, 2, 3),
        state  = c('CA', 'CA', 'CA'),
        year   = c(2023, 2023, 2023),
        mstat  = c('single', 'single', 'married, jointly'),
        pwages = c(pwage, swage, pwage), # primary wages
        swages = c(    0,     0, swage),
        
        # Assume additional 5% earned via the following:
        #dividends = c(pwage, swage, pwage + swage) * 0.05,
        #intrec = c(pwage, swage, pwage + swage) * 0.05,
        #stcg = c(pwage, swage, pwage + swage) * 0.05,
        #ltcg = c(pwage, swage, pwage + swage) * 0.05,
        
        #dividends # Dividend income (qualified dividends only for 2003 on).
        #intrec # Interest income received (+/-).
        #stcg # Short Term Capital Gains or losses (+/-).
        #ltcg # Long Term Capital Gains or losses (+/-).
        
        page   = c(page, sage, page), # primary age
        sage   = c(   0,    0, sage)
      )
      
      family_taxes <- taxsim_calculate_taxes(
        .data = family_income,
        marginal_tax_rates = 'Wages',
        return_all_information = FALSE
      )
  
      family_taxes['totaltax'] = family_taxes['fiitax'] + family_taxes['siitax'] + family_taxes['tfica']
      
      single <- max(family_taxes['totaltax'][[1,1]] + family_taxes['totaltax'][[2,1]], 0)
      married <- max(family_taxes['totaltax'][[3,1]], 0)
      
      penalty <- 0
      if (single > 0) {
        penalty <- (married / single) - 1
      }
  
      results[[i]] <- c(
        "pwage" = pwage, 
        "swage" = swage, 
        "single" = single, 
        "married" = married, 
        "penalty" = penalty
      )
    }
  }
  
  results <- do.call(rbind, results)
  results <- as.data.frame(results)
  
  write.csv(results, "penalty.csv")
  
  return (results)
}

# TODO Uncomment if you wish to generate
#results <- generate()



library(ggplot2)
library(cowplot)


make_fullsize <- function() structure("", class = "fullsizebar")

ggplot_add.fullsizebar <- function(obj, g, name = "fullsizebar") {
  h <- ggplotGrob(g)$heights
  panel <- which(grid::unitType(h) == "null")
  
  # Adjust the unit. RStudio requires 0.75, but saving as SVG requires 1.
  panel_height <- unit(1, "npc") - sum(h[-panel]) 
  
  g + 
    guides(fill = guide_colorbar(barheight = panel_height ,
                                 title.position = "right")) +
    theme(legend.title = element_text(angle = -90, hjust = 0.5))
}



# Chart

ggplot(results,
       aes(pwage, swage, fill = penalty)
) +
  geom_raster(hjust = 1, vjust = 1) +
  labs(
    x="Primary Income ($)",
    y="Spouse Income ($)",
    fill="Penalty / Bonus"
  ) +
  coord_cartesian(
    expand = FALSE,   # Removes margin around raster
    xlim = c(0, 1000000), 
    ylim = c(0, 1000000),
  ) +
  scale_x_continuous(labels = comma) +
  scale_y_continuous(labels = comma) +
  scale_fill_steps2(
    breaks=seq(-0.1, 0.05, by=0.01),

    limits=c(-0.10, 0.051),

    low="seagreen",
    mid="white",
    high="firebrick",

    labels = scales::percent_format(accuracy = 1),
  ) +
  make_fullsize()


ggsave("penalty.svg")
