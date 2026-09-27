import test from 'node:test';
import assert from 'node:assert/strict';
import {toBase,recipeNeeds,planNeeds,shortageRows,suggestions} from '../domain.js';

const items=[{id:'rice',name:'برنج',unit:'g',stock:50000,minimum:20000,reorder:25000,maximum:70000,lastPrice:250},{id:'oil',name:'روغن',unit:'ml',stock:500,minimum:1000,reorder:2000,maximum:5000,lastPrice:100}];
const recipes=[{id:'meal',name:'پلو',servings:10}];
const ingredients=[{recipeId:'meal',itemId:'rice',quantity:2,unit:'kg',factor:1},{recipeId:'meal',itemId:'oil',quantity:100,unit:'ml',factor:1}];

test('unit conversion rejects incompatible dimensions',()=>{assert.equal(toBase(2,'kg','g'),2000);assert.throws(()=>toBase(1,'l','g'),/سازگار/)});
test('recipe scales and sums needs',()=>{assert.equal(recipeNeeds(ingredients,20,10,items).get('rice'),4000);assert.equal(planNeeds([{recipeId:'meal',portions:100},{recipeId:'meal',portions:50}],recipes,ingredients,items).get('rice'),30000)});
test('shortage uses available inventory and never goes negative',()=>{const rows=shortageRows(new Map([['rice',60000],['oil',100]]),items);assert.equal(rows.length,1);assert.equal(rows[0].shortage,10000)});
test('purchase suggestion reaches target stock',()=>{const rows=suggestions(items,new Map([['rice',60000]]));assert.equal(rows.find(x=>x.item.id==='rice').suggested,20000);assert.equal(rows.find(x=>x.item.id==='oil').suggested,4500)});
