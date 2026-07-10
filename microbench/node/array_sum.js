function buildAndSum(size) {
  const list = [];
  for (let i = 0; i < size; i++) {
    list.push(i);
  }

  let total = 0;
  for (const item of list) {
    total += item;
  }
  return total;
}

const result = buildAndSum(1000000);
console.log(result);
