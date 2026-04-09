const { DataTypes } = require('sequelize');
const sequelize = require('../db/sequelize');

const NOD = sequelize.define('nod', {
  ri: { type: DataTypes.STRING(24), primaryKey: true, allowNull: false },
  ty: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 14 },
  sid: { type: DataTypes.STRING },
  int_cr: { type: DataTypes.STRING },
  rn: { type: DataTypes.STRING, allowNull: false },
  pi: { type: DataTypes.STRING },
  et: { type: DataTypes.STRING(20) },
  ct: { type: DataTypes.STRING(20) },
  lt: { type: DataTypes.STRING(20) },
  acpi: { type: DataTypes.ARRAY(DataTypes.STRING) },
  lbl: { type: DataTypes.ARRAY(DataTypes.STRING) },
  cr: { type: DataTypes.STRING },
  ni: { type: DataTypes.STRING },
  hcl: { type: DataTypes.INTEGER },
  mgca: { type: DataTypes.ARRAY(DataTypes.STRING) },
  loc: { type: DataTypes.GEOMETRY('GEOMETRY', 4326) },
}, {
  tableName: 'nod',
  timestamps: false,
});

module.exports = NOD;
