import re

with open("MGÖ_GA_Tarım_Afrika.qmd", "r", encoding="utf-8") as f:
    content = f.read()

# Fix typos and stylistic errors
content = content.replace("Kamu Bölümü", "Kamu Yönetimi Bölümü")
content = content.replace("Olden eve Jackson", "Olden ve Jackson")
content = content.replace("belirnemiştir", "belirlenmiştir")
content = content.replace("hollanda hastalığı", "Hollanda Hastalığı")
content = content.replace("yapısal dönüşüm", "Yapısal Dönüşüm") # This might be too broad; let's stick to specific ones
content = content.replace("hollanda hastalığı", "Hollanda Hastalığı")
content = content.replace("yapısal kararl ılığını", "yapısal kararlılığını")

# Remove first YAML block title since Springer Title page should be structured in text, but Quarto YAML is fine. 
# Springer wants Title Page to have specific format. We can just append JEL and Declarations.

declarations = """

**JEL Classification:** Q10 (Agriculture: General), O13 (Agriculture • Natural Resources • Energy • Environment • Other Primary Products), C45 (Neural Networks and Related Topics), O55 (Economywide Country Studies: Africa)

# Statements and Declarations

- **Funding:** The authors declare that no financial support was received for the research, authorship, and/or publication of this article.
- **Competing Interests:** The authors declare they have no financial or non-financial interests that are directly or indirectly related to the work submitted for publication.
- **Data Availability:** The datasets used and/or analyzed during the current study are available from the corresponding author on reasonable request.
- **Code Availability:** The R codes and models generated during the current study are available from the corresponding author on reasonable request.
- **Author Contributions:** All authors contributed equally to the study conception, design, data analysis, and manuscript preparation.

"""

content = content.replace("Keywords: Artificial Neural Networks, Sub-Saharan Africa, Agricultural GDP, Structural Transformation, Dutch Disease, Model Robustness.", 
"Keywords: Artificial Neural Networks, Sub-Saharan Africa, Agricultural GDP, Structural Transformation, Dutch Disease, Model Robustness." + declarations)

# Save as new qmd file
with open("ECOP_GA_Tarim_Afrika.qmd", "w", encoding="utf-8") as f:
    f.write(content)

print("ECOP_GA_Tarim_Afrika.qmd created successfully.")
