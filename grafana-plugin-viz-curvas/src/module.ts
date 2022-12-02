import { PanelPlugin } from '@grafana/data';
import { SimpleOptions } from './types';
import { SimplePanel } from './SimplePanel';

export const plugin = new PanelPlugin<SimpleOptions>(SimplePanel).setPanelOptions(builder => {
  return builder.addRadio({
    path: 'motor',
    name: 'Motor',
    defaultValue: 'm1',
    settings: {
      options: [
        {
          value: 'm1',
          label: 'm1',
        },
        {
          value: 'm2',
          label: 'm2',
        },
      ],
    },
  });
});
