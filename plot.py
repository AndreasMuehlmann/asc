import sys

import matplotlib.pyplot as plt
import pandas as pd


assert len(sys.argv) == 2, f'1 parameter, file name, needed ({len(sys.argv) - 1} parameters given).'

plt.style.use('fivethirtyeight')
plt.tight_layout()

data = pd.read_csv(sys.argv[1])

x_axis_column = data.columns[0]
for column in data.columns[1:2]:
    plt.plot(data[x_axis_column], data[column], label=column, linewidth=2)
plt.legend(loc='upper left')
plt.tight_layout()
plt.show()
