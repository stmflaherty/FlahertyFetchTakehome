
# This Python code has been used just to create graphs from thr accompanying SQL tables using the matplotlib library.
# The code to create all of the graphs exists in this one script, and the code unique to each graph cna be commented in
# or out to switch between the graph being drawn. All of the graphs are lettered and available to see in a separate
# image file.

import pyodbc
import pandas as pd
import matplotlib.pyplot as plt

# Connection details
server = 'DESKTOP-SFOBUVB'
database = 'master'
conn = pyodbc.connect('DRIVER={SQL Server};SERVER=' + server +';PORT=1433' +';DATABASE=' + database + ';Trusted_Connection=yes')
cursor = conn.cursor()

"""
######## Graph A: Users by Month #########

# Execute query and fetch data
query = 'SELECT * FROM UsersByMonth'
df = pd.read_sql(query, conn)

#Ensuring that the x-axis is sorted in the graph
df = df.sort_values(by='YearMonth')

plt.bar(df['YearMonth'], df['NewUsers'])
plt.xlabel('YearMonth')
plt.ylabel('NewUsers')
plt.title('Users by Month')

plt.xticks(rotation=90, fontsize=8)

############################################
"""

"""
######## Graph B: Transactions by Month #########

# Execute query and fetch data
query = 'SELECT * FROM TransactionsByMonth'
df = pd.read_sql(query, conn)

#Ensuring that the x-axis is sorted in the graph
df = df.sort_values(by='YearMonth')

plt.bar(df['YearMonth'], df['Transactions'])
plt.xlabel('YearMonth')
plt.ylabel('Transactions')
plt.title('Transactions by Month')

plt.xticks(rotation=90, fontsize=8)

############################################
"""

#"""
######## Graph C: Transactions by Product Category #########

# Execute query and fetch data
query = 'SELECT * FROM TransactionsByProduct'
df = pd.read_sql(query, conn)

#Ensuring that the x-axis is sorted in the graph
df = df.sort_values(by='Transactions')

plt.bar(df['maincategory'], df['Transactions'])
plt.xlabel('maincategory')
plt.ylabel('Transactions')
plt.title('Transactions by Product Category')

plt.xticks(rotation=90, fontsize=8)

############################################
#"""

plt.show()

# Close connection
conn.close()

