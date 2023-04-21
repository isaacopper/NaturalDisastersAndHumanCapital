
################### Expanded Regression Discontinuity ##########################

# Clear console.
cat("\014")

# Remove Plots
#dev.off(dev.list()["RStudioGD"]) # Apply dev.off() & dev.list()

# Remove all files from workspace - do this every time so we don't use a file archived to the workspace.
rm(list = ls())

# Change Directory
setwd("/Users/iopper/Documents/ResearchProjects/NaturalDisastersAndHumanCapital/")

################################## Import the packages #########################
library('ggplot2')
library('tibble')
library('tidyr')
library('dplyr')

library('collapse')

library('mgcv')
#install.packages('gratia')
library('gratia')

library('rdrobust')
library('haven')

################################## IPEDS #########################
full_data <- read_dta("cleaned_data/college_enrollment/main_data.dta")

# Normalization
a <- full_data %>% filter(log_percap_damages > 0) %>% filter(log_percap_damages < 1) %>% select(l_d_enrollment_ft, ave_enroll) %>% drop_na()
l_norm <- weighted.mean(a$l_d_enrollment_ft, a$ave_enroll)
a <- full_data %>% filter(log_percap_damages > 0) %>% filter(log_percap_damages < 1) %>% select(d_enrollment_ft, ave_enroll) %>% drop_na()
norm <- weighted.mean(a$d_enrollment_ft, a$ave_enroll)

# Graph
#ipeds_graph <- ggplot(full_data %>% filter(log_percap_damages > 0), aes(x = log_percap_damages, weight = ave_enroll)) + 
#  geom_smooth(aes(y = d_enrollment_ft - norm, colour = "Post-Disaster", linetype = "Post-Disaster"), formula = y ~ poly(x, 3)) + geom_smooth(aes(y = l_d_enrollment_ft - l_norm, colour = "Pre-Disaster", linetype = "Post-Disaster"), formula = y ~ poly(x, 3), se = FALSE) + 
#  theme_bw() +  labs(x="Log Per Capita Property Damage", y = "College Enrollment") + 
#  scale_color_manual(breaks = c("Post-Disaster", "Pre-Disaster"), values = c("Post-Disaster" = "blue", "Pre-Disaster" = "red")) + scale_linetype_manual(breaks = c("Post-Disaster", "Pre-Disaster"), values = c("Post-Disaster" ='solid', "Pre-Disaster" ='dashed')) +
#  theme(legend.position="bottom") + guides(color = guide_legend(title = ""))
ipeds_graph <- ggplot(full_data %>% filter(log_percap_damages > 0), aes(x = log_percap_damages, weight = ave_enroll)) + 
  geom_smooth(aes(y = d_enrollment_ft - norm, colour = "Post-Disaster"), formula = y ~ poly(x, 3)) + 
  geom_smooth(aes(y = l_d_enrollment_ft - l_norm, colour = "Pre-Disaster"), linetype = "dashed", formula = y ~ poly(x, 3), se = FALSE) + 
  theme_bw() +  labs(x="Log Per Capita Property Damage", y = "College Enrollment") + 
  scale_color_manual(breaks = c("Post-Disaster", "Pre-Disaster"), values = c("Post-Disaster" = "blue", "Pre-Disaster" = "red")) +
  theme(legend.position="bottom") + guides(color = guide_legend(title = ""))

ipeds_graph

ipeds_graph <- ggplot(full_data %>% filter(log_percap_damages > 0), aes(x = log_percap_damages, weight = ave_enroll)) + 
  geom_smooth(aes(y = d_enrollment_ft - norm, colour = "Post-Disaster"), formula = y ~ s(x, bs = "cs", k = 5)) + 
  geom_smooth(aes(y = l_d_enrollment_ft - l_norm, colour = "Pre-Disaster"), linetype = "dashed",formula = y ~ s(x, bs = "cs", k = 5), se = FALSE) + 
  theme_bw() +  labs(x="Log Per Capita Property Damage", y = "College Enrollment") + 
  scale_color_manual(breaks = c("Post-Disaster", "Pre-Disaster"), values = c("Post-Disaster" = "blue", "Pre-Disaster" = "red")) +
  theme(legend.position="bottom") + guides(color = guide_legend(title = ""))

#pdf("output/college_enrollment/impacts.pdf", height = 4, width = 6)
ipeds_graph
#dev.off()

#pdf("output/college_enrollment/impacts_bothSE.pdf", height = 4, width = 6)
ggplot(full_data %>% filter(log_percap_damages > 0), aes(x = log_percap_damages, weight = ave_enroll)) + 
  geom_smooth(aes(y = d_enrollment_ft - norm, colour = "Post-Disaster"), formula = y ~ s(x, bs = "cs", k = 5)) + 
  geom_smooth(aes(y = l_d_enrollment_ft - l_norm, colour = "Pre-Disaster"), linetype = "dashed",formula = y ~ s(x, bs = "cs", k = 5), se = TRUE) + 
  theme_bw() +  labs(x="Log Per Capita Property Damage", y = "College Enrollment") + 
  scale_color_manual(breaks = c("Post-Disaster", "Pre-Disaster"), values = c("Post-Disaster" = "blue", "Pre-Disaster" = "red")) +
  theme(legend.position="bottom") + guides(color = guide_legend(title = ""))
#dev.off()

ipeds_graph_adj <- ggplot(full_data %>% mutate(log_percap_damages= log_percap_damages - log_index) %>% filter(log_percap_damages > 0) , aes(x = log_percap_damages, weight = ave_enroll)) + 
  geom_smooth(aes(y = d_enrollment_ft - norm, colour = "Post-Disaster"), formula = y ~ s(x, bs = "cs", k = 5)) + 
  geom_smooth(aes(y = l_d_enrollment_ft - l_norm, colour = "Pre-Disaster"), linetype = "dashed",formula = y ~ s(x, bs = "cs", k = 5), se = FALSE) + 
  theme_bw() +  labs(x="Log Per Capita Property Damage", y = "College Enrollment") + 
  scale_color_manual(breaks = c("Post-Disaster", "Pre-Disaster"), values = c("Post-Disaster" = "blue", "Pre-Disaster" = "red")) +
  theme(legend.position="bottom") + guides(color = guide_legend(title = ""))




################################## SEDA #########################
full_data <- read_dta("cleaned_data/seda/main_data.dta")

# Normalization
a <- full_data %>% filter(log_percap_damages > 0) %>% filter(log_percap_damages < 1) %>% select(l_d_all, ave_weight) %>% drop_na()
l_norm <- weighted.mean(a$l_d_all, a$ave_weight)
a <- full_data %>% filter(log_percap_damages > 0) %>% filter(log_percap_damages < 1) %>% select(d_all, ave_weight) %>% drop_na()
norm <- weighted.mean(a$d_all, a$ave_weight)

# Graph
seda_graph <- ggplot(full_data %>% filter(log_percap_damages > 0), aes(x = log_percap_damages, weight = ave_weight)) + 
  geom_smooth(aes(y = d_all - norm, colour = "Post-Disaster"), formula = y ~ poly(x, 1)) + 
  geom_smooth(aes(y = l_d_all - l_norm, colour = "Pre-Disaster"), linetype = 'dashed', formula = y ~ poly(x, 1), se = FALSE) + 
  theme_bw() +  labs(x="Log Per Capita Property Damage", y = "Avg. Test Scores") + 
  scale_color_manual(breaks = c("Post-Disaster", "Pre-Disaster"), values = c("Post-Disaster" = "blue", "Pre-Disaster" = "red"))  +
  theme(legend.position="bottom") + guides(color = guide_legend(title = ""))

seda_graph

seda_graph <- ggplot(full_data %>% filter(log_percap_damages > 0), aes(x = log_percap_damages, weight = ave_weight)) + 
  geom_smooth(aes(y = d_all - norm, colour = "Post-Disaster"), formula = y ~ s(x, bs = "cs", k = 5)) + 
  geom_smooth(aes(y = l_d_all - l_norm, colour = "Pre-Disaster"), linetype = 'dashed', formula = y ~ s(x, bs = "cs", k = 5), se = FALSE) + 
  theme_bw() +  labs(x="Log Per Capita Property Damage", y = "Avg. Test Scores") + 
  scale_color_manual(breaks = c("Post-Disaster", "Pre-Disaster"), values = c("Post-Disaster" = "blue", "Pre-Disaster" = "red"))  +
  theme(legend.position="bottom") + guides(color = guide_legend(title = ""))


#pdf("output/seda/impacts.pdf", height = 4, width = 6)
seda_graph
#dev.off()

#pdf("output/seda/impacts_bothSE.pdf", height = 4, width = 6)
ggplot(full_data %>% filter(log_percap_damages > 0), aes(x = log_percap_damages, weight = ave_weight)) + 
  geom_smooth(aes(y = d_all - norm, colour = "Post-Disaster"), formula = y ~ s(x, bs = "cs", k = 5)) + 
  geom_smooth(aes(y = l_d_all - l_norm, colour = "Pre-Disaster"), linetype = 'dashed', formula = y ~ s(x, bs = "cs", k = 5), se = TRUE) + 
  theme_bw() +  labs(x="Log Per Capita Property Damage", y = "Avg. Test Scores") + 
  scale_color_manual(breaks = c("Post-Disaster", "Pre-Disaster"), values = c("Post-Disaster" = "blue", "Pre-Disaster" = "red"))  +
  theme(legend.position="bottom") + guides(color = guide_legend(title = ""))
#dev.off()

seda_graph_adj <- ggplot(full_data  %>% mutate(log_percap_damages = log_percap_damages - log_index) %>% filter(log_percap_damages > 0), aes(x = log_percap_damages, weight = ave_weight)) + 
  geom_smooth(aes(y = d_all - norm, colour = "Post-Disaster"), formula = y ~ s(x, bs = "cs", k = 5)) + 
  geom_smooth(aes(y = l_d_all - l_norm, colour = "Pre-Disaster"), linetype = 'dashed', formula = y ~ s(x, bs = "cs", k = 5), se = FALSE) + 
  theme_bw() +  labs(x="Log Per Capita Property Damage", y = "Avg. Test Scores") + 
  scale_color_manual(breaks = c("Post-Disaster", "Pre-Disaster"), values = c("Post-Disaster" = "blue", "Pre-Disaster" = "red"))  +
  theme(legend.position="bottom") + guides(color = guide_legend(title = ""))



#seda_graph <- ggplot(full_data %>% filter(log_percap_damages > 0), aes(x = log_percap_damages, weight = ave_weight)) + geom_smooth(aes(y = d_all - norm, colour = "Post-Disaster", linetype = 'Post-Disaster'), formula = y ~ poly(x, 1)) + 
#  geom_smooth(aes(y = l_d_all - l_norm, colour = "Pre-Disaster", linetype = 'Post-Disaster'), formula = y ~ poly(x, 1), se = FALSE) + 
#  theme_bw() +  labs(x="Log Per Capita Property Damage", y = "Avg. Test Scores") + 
#  scale_color_manual(breaks = c("Post-Disaster", "Pre-Disaster"), values = c("Post-Disaster" = "blue", "Pre-Disaster" = "red")) + scale_linetype_manual(breaks = c("Post-Disaster", "Pre-Disaster"), values = c("Post-Disaster" ='solid', "Pre-Disaster" ='dashed')) +
#  theme(legend.position="bottom") + guides(color = guide_legend(title = ""))


################################## Graduation #########################
full_data <- read_dta("cleaned_data/graduation/main_data.dta")

# Normalization
a <- full_data %>% filter(log_percap_damages > 0) %>% filter(log_percap_damages < 1) %>% select(l_d_grad_rate, ave_enroll) %>% drop_na()
l_norm <- weighted.mean(a$l_d_grad_rate, a$ave_enroll) - .05
a <- full_data %>% filter(log_percap_damages > 0) %>% filter(log_percap_damages < 1) %>% select(d_grad_rate, ave_enroll) %>% drop_na()
norm <- weighted.mean(a$d_grad_rate, a$ave_enroll) + .05
a <- full_data %>% filter(log_percap_damages > 0) %>% filter(log_percap_damages < 1) %>% select(f_d_grad_rate, ave_enroll) %>% drop_na()
f_norm <- weighted.mean(a$f_d_grad_rate, a$ave_enroll)

graduation_graph <- ggplot(full_data %>% filter(log_percap_damages > 0), aes(x = log_percap_damages, weight = ave_enroll)) + 
  geom_smooth(aes(y = d_grad_rate - norm, color = "Post-Disaster"), formula = y ~ poly(x, 1)) + 
  geom_smooth(aes(y = f_d_grad_rate - f_norm, color = 'Two Years Post-Disaster'), linetype = 'dotdash', formula = y ~ poly(x, 1)) + 
  geom_smooth(aes(y = l_d_grad_rate  - l_norm, color = 'Pre-Disaster'), linetype = 'dashed', formula = y ~ poly(x, 1), se = FALSE) + 
  theme_bw() + labs(x="Log Per Capita Property Damage", y = "HS Graduation Rate") +
  scale_color_manual(breaks = c("Post-Disaster", "Pre-Disaster", "Two Years Post-Disaster"), values = c("Post-Disaster" = "#574AE2", "Pre-Disaster" = "#DE1A1A", "Two Years Post-Disaster" = "#29BF12")) +
  theme(legend.position="bottom") + guides(color = guide_legend(title = ""))

graduation_graph

graduation_graph <- ggplot(full_data %>% filter(log_percap_damages > 0), aes(x = log_percap_damages, weight = ave_enroll)) + 
  geom_smooth(aes(y = d_grad_rate - norm, color = "Post-Disaster"), formula = y ~ s(x, bs = "cs", k = 5)) + 
  geom_smooth(aes(y = f_d_grad_rate - f_norm, color = 'Two Years Post-Disaster'), linetype = 'dotdash', formula = y ~ s(x, bs = "cs", k = 5)) + 
  geom_smooth(aes(y = l_d_grad_rate  - l_norm, color = 'Pre-Disaster'), linetype = 'dashed', formula = y ~ s(x, bs = "cs", k = 5), se = FALSE) + 
  theme_bw() + labs(x="Log Per Capita Property Damage", y = "HS Graduation Rate") +
  scale_color_manual(breaks = c("Post-Disaster", "Pre-Disaster", "Two Years Post-Disaster"), values = c("Post-Disaster" = "#574AE2", "Pre-Disaster" = "#DE1A1A", "Two Years Post-Disaster" = "#29BF12")) +
  theme(legend.position="bottom") + guides(color = guide_legend(title = ""))

#pdf("output/graduation/impacts.pdf", height = 4, width = 6)
graduation_graph
#dev.off()

#pdf("output/graduation/impacts_bothSE.pdf", height = 4, width = 6)
ggplot(full_data %>% filter(log_percap_damages > 0), aes(x = log_percap_damages, weight = ave_enroll)) + 
  geom_smooth(aes(y = d_grad_rate - norm, color = "Post-Disaster"), formula = y ~ s(x, bs = "cs", k = 5)) + 
  geom_smooth(aes(y = f_d_grad_rate - f_norm, color = 'Two Years Post-Disaster'), linetype = 'dotdash', formula = y ~ s(x, bs = "cs", k = 5)) + 
  geom_smooth(aes(y = l_d_grad_rate  - l_norm, color = 'Pre-Disaster'), linetype = 'dashed', formula = y ~ s(x, bs = "cs", k = 5), se = TRUE) + 
  theme_bw() + labs(x="Log Per Capita Property Damage", y = "HS Graduation Rate") +
  scale_color_manual(breaks = c("Post-Disaster", "Pre-Disaster", "Two Years Post-Disaster"), values = c("Post-Disaster" = "#574AE2", "Pre-Disaster" = "#DE1A1A", "Two Years Post-Disaster" = "#29BF12")) +
  theme(legend.position="bottom") + guides(color = guide_legend(title = ""))
#dev.off()

graduation_graph_adj <- ggplot(full_data  %>% mutate(log_percap_damages = log_percap_damages - log_index) %>% filter(log_percap_damages > 0), aes(x = log_percap_damages, weight = ave_enroll)) + 
  geom_smooth(aes(y = d_grad_rate - norm - .1, color = "Post-Disaster"), formula = y ~ s(x, bs = "cs", k = 5)) + 
  geom_smooth(aes(y = f_d_grad_rate - f_norm + .1, color = 'Two Years Post-Disaster'), linetype = 'dotdash', formula = y ~ s(x, bs = "cs", k = 5)) + 
  geom_smooth(aes(y = l_d_grad_rate  - l_norm - .1, color = 'Pre-Disaster'), linetype = 'dashed', formula = y ~ s(x, bs = "cs", k = 5), se = FALSE) + 
  theme_bw() + labs(x="Log Per Capita Property Damage", y = "HS Graduation Rate") +
  scale_color_manual(breaks = c("Post-Disaster", "Pre-Disaster", "Two Years Post-Disaster"), values = c("Post-Disaster" = "#574AE2", "Pre-Disaster" = "#DE1A1A", "Two Years Post-Disaster" = "#29BF12")) +
  theme(legend.position="bottom") + guides(color = guide_legend(title = ""))




#ggplot(full_data %>% filter(log_percap_damages > 0), aes(x = log_percap_damages, weight = ave_enroll)) + geom_smooth(aes(y = d_grad_rate - norm, color = "Post-Disaster", linetype = 'Post-Disaster'), formula = y ~ poly(x, 1)) + 
#  geom_smooth(aes(y = f_d_grad_rate - f_norm, color = 'Two Years Post-Disaster', linetype = 'Two Years Post-Disaster'), formula = y ~ poly(x, 1)) + geom_smooth(aes(y = l_d_grad_rate  - l_norm, color = 'Pre-Disaster', linetype = 'Pre-Disaster'), formula = y ~ poly(x, 1), se = FALSE) + 
#  theme_bw() +  labs(x="Log Per Capita Property Damage", y = "HS Graduation Rate") +
#  scale_color_manual(breaks = c("Post-Disaster", "Pre-Disaster", "Two Years Post-Disaster"), values = c("Post-Disaster" = "#574AE2", "Pre-Disaster" = "#DE1A1A", "Two Years Post-Disaster" = "#29BF12")) + scale_linetype_manual(breaks = c("Post-Disaster", "Pre-Disaster", "Two Years Post-Disaster"), values = c("Post-Disaster" ='solid', "Pre-Disaster" ='dashed', "Two Years Post-Disaster" = 'dotdash')) +
#  theme(legend.position="bottom") + guides(color = guide_legend(title = ""))

#, color = "#574AE2"
#, color = "#DE1A1A"
#, colour = "#29BF12"

################################## Migration #########################
full_data <- read_dta("cleaned_data/migration/main_data.dta")

# Normalization
a <- full_data %>% filter(log_percap_damages > 0) %>% filter(log_percap_damages < 1) %>% select(l_netmig_rate, ave_weight) %>% drop_na()
l_norm <- weighted.mean(a$l_netmig_rate, a$ave_weight)
a <- full_data %>% filter(log_percap_damages > 0) %>% filter(log_percap_damages < 1) %>% select(netmig_rate, ave_weight) %>% drop_na()
norm <- weighted.mean(a$netmig_rate, a$ave_weight)

migration_graph <- ggplot(full_data %>% filter(log_percap_damages > 0), aes(x = log_percap_damages, weight = ave_weight)) + 
  geom_smooth(aes(y = netmig_rate - norm, color = "Post-Disaster"), formula = y ~ poly(x,3)) + 
  geom_smooth(aes(y = l_netmig_rate - l_norm, color = "Pre-Disaster"), formula = y ~ poly(x,3), se = FALSE, linetype = 'dashed') + 
  theme_bw() + labs(x="Log Per Capita Property Damage", y = "Net Migration Rate") +
  scale_color_manual(breaks = c("Post-Disaster", "Pre-Disaster"), values = c("Post-Disaster" = "#574AE2", "Pre-Disaster" = "#DE1A1A")) +
  theme(legend.position="bottom", legend.title = element_blank(),legend.key = element_rect(fill = 'white'))

migration_graph <- ggplot(full_data %>% filter(log_percap_damages > 0), aes(x = log_percap_damages, weight = ave_weight)) + 
  geom_smooth(aes(y = netmig_rate - norm, color = "Post-Disaster"), formula = y ~ s(x, bs = "cs", k = 5)) + 
  geom_smooth(aes(y = l_netmig_rate - l_norm, color = "Pre-Disaster"), formula = y ~ s(x, bs = "cs", k = 5), se = FALSE, linetype = 'dashed') + 
  theme_bw() + labs(x="Log Per Capita Property Damage", y = "Net Migration Rate") +
  scale_color_manual(breaks = c("Post-Disaster", "Pre-Disaster"), values = c("Post-Disaster" = "#574AE2", "Pre-Disaster" = "#DE1A1A")) +
  theme(legend.position="bottom", legend.title = element_blank(),legend.key = element_rect(fill = 'white'))


#pdf("output/migration/impacts.pdf", height = 4, width = 6)
migration_graph
#dev.off()


#pdf("output/migration/impacts_bothSE.pdf", height = 4, width = 6)
ggplot(full_data %>% filter(log_percap_damages > 0), aes(x = log_percap_damages, weight = ave_weight)) + 
  geom_smooth(aes(y = netmig_rate - norm, color = "Post-Disaster"), formula = y ~ s(x, bs = "cs", k = 5)) + 
  geom_smooth(aes(y = l_netmig_rate - l_norm, color = "Pre-Disaster"), formula = y ~ s(x, bs = "cs", k = 5), se = TRUE, linetype = 'dashed') + 
  theme_bw() + labs(x="Log Per Capita Property Damage", y = "Net Migration Rate") +
  scale_color_manual(breaks = c("Post-Disaster", "Pre-Disaster"), values = c("Post-Disaster" = "#574AE2", "Pre-Disaster" = "#DE1A1A")) +
  theme(legend.position="bottom", legend.title = element_blank(),legend.key = element_rect(fill = 'white'))
#dev.off()

migration_graph_adj <- ggplot(full_data  %>% filter(log_percap_damages > 0) , aes(x = log_percap_damages, weight = ave_weight)) + 
  geom_smooth(aes(y = netmig_rate - norm, color = "Post-Disaster"), formula = y ~ s(x, bs = "cs", k = 5)) + 
  geom_smooth(aes(y = l_netmig_rate - l_norm, color = "Pre-Disaster"), formula = y ~ s(x, bs = "cs", k = 5), se = FALSE, linetype = 'dashed') + 
  theme_bw() + labs(x="Log Per Capita Property Damage", y = "Net Migration Rate") +
  scale_color_manual(breaks = c("Post-Disaster", "Pre-Disaster"), values = c("Post-Disaster" = "#574AE2", "Pre-Disaster" = "#DE1A1A")) +
  theme(legend.position="bottom", legend.title = element_blank(),legend.key = element_rect(fill = 'white'))


################################## Combine Adjusted Graphs #########################

pdf("output/seda/impacts_seda_deflated.pdf", height = 4, width = 6)
print(seda_graph_adj)
dev.off()

pdf("output/college_enrollment/impacts_enrollment_deflated.pdf", height = 4, width = 6)
print(ipeds_graph_adj)
dev.off()

pdf("output/migration/impacts_migration_deflated.pdf", height = 4, width = 6)
print(migration_graph_adj)
dev.off()

pdf("output/graduation/impacts_graduation_deflated.pdf", height = 4, width = 6)
print(graduation_graph_adj)
dev.off()





