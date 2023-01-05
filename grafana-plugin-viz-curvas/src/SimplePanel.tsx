import React from 'react';
import { PanelProps } from '@grafana/data';
import { SimpleOptions } from 'types';
import * as d3 from 'd3';

interface Props extends PanelProps<SimpleOptions> {}

export const SimplePanel: React.FC<Props> = ({ options, data, width, height, id }) => {
  console.log('data.series:');
  console.log(data.series);
  const svgContainer = React.useRef(null);
  React.useEffect(() => {
    const t0 = performance.now();
    const consumo = 'Consumo_' + options.motor;
    const flat_points = data.series
      .flatMap(k => k.fields)
      .flatMap(field => field.values.toArray())
      .flatMap(k => {
        const _id = k.resourceCode + '-' + k.manoeuvre_name + '-' + k['@timestamp'];
        return Object.entries(k)
          .filter(([key, value]) => key.substr(0, consumo.length) === consumo)
          .map(([k, v]) => ({ _id: _id, n: 12 * parseInt(k.substr(11, 14), 10), v: v as number }));
      })
      .flatMap(x => x);
    flat_points.sort((i1, i2) => i1.n - i2.n);
    console.log(flat_points);
    const margin = { top: 10, right: 30, bottom: 30, left: 60 },
      rwidth = width - margin.left - margin.right,
      rheight = height - margin.top - margin.bottom;

    // append the svg object to the body of the page
    const panelid = 'supersvgviz---' + id;
    d3.select('#' + panelid).remove();
    const svg = d3
      .select(svgContainer.current)
      .append('svg')
      .attr('id', panelid)
      .attr('width', rwidth + margin.left + margin.right)
      .attr('height', rheight + margin.top + margin.bottom)
      .append('g')
      .attr('transform', 'translate(' + margin.left + ',' + margin.top + ')');

    // group the data: I want to draw one line per group
    type L = { _id: string; n: Number; v: Number };
    const sumstat = d3
      .nest<L>()
      .key(d => d._id)
      .entries(flat_points);
    // nest function allows to group the calculation per level of a factor

    // Add X axis --> it is a date format
    const x = d3
      .scaleLinear()
      .domain([d3.min(flat_points, d => d.n) as number, d3.max(flat_points, d => d.n) as number])
      .range([0, rwidth]);
    svg
      .append('g')
      .attr('transform', 'translate(0,' + rheight + ')')
      .call(d3.axisBottom(x).ticks(5));

    // Add Y axis
    const y = d3
      .scaleLinear()
      .domain([0, d3.max(flat_points, d => d.v) as number])
      .range([rheight, 0]);
    svg.append('g').call(d3.axisLeft(y));

    var seed = -1;
    // color palette
    const colors = ['#e41a1c', '#377eb8', '#4daf4a', '#984ea3', '#ff7f00', '#ffff33', '#a65628', '#f781bf', '#999999'];
    const color = () => {
      seed += 1;
      return colors[seed % colors.length];
    };

    type V = { n: Number; v: Number };
    // Draw the line
    svg
      .selectAll('.line')
      .data(sumstat)
      .enter()
      .append('path')
      .attr('fill', 'none')
      .attr('stroke', color)
      .attr('stroke-width', 1.5)
      .attr('d', function(d) {
        return d3
          .line<V>()
          .x(function(d) {
            return x(d.n);
          })
          .y(function(d) {
            return y(+d.v);
          })(d.values);
      });

    console.log('Elapsed refresh time: ' + (performance.now() - t0) + 'ms');
  }, [options, data, width, height, svgContainer, id]);

  return <div ref={svgContainer} />;
};
