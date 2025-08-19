import React, { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardHeader, CardTitle, CardContent, CardFooter } from '@/components/ui/card';

const LoanCalculator = () => {
  const [loanAmount, setLoanAmount] = useState('');
  const [interestRate, setInterestRate] = useState('');
  const [loanTerm, setLoanTerm] = useState('');
  const [monthlyPayment, setMonthlyPayment] = useState(null);
  const [totalPayment, setTotalPayment] = useState(null);
  const [totalInterest, setTotalInterest] = useState(null);

  const calculateLoan = () => {
    const principal = parseFloat(loanAmount);
    const rate = parseFloat(interestRate) / 100 / 12;
    const term = parseFloat(loanTerm) * 12;

    if (principal > 0 && rate > 0 && term > 0) {
      const x = Math.pow(1 + rate, term);
      const monthly = (principal * x * rate) / (x - 1);
      const total = monthly * term;
      const interest = total - principal;

      setMonthlyPayment(monthly.toFixed(2));
      setTotalPayment(total.toFixed(2));
      setTotalInterest(interest.toFixed(2));
    }
  };

  return (
    <Card className="w-full max-w-md mx-auto">
      <CardHeader>
        <CardTitle className="text-2xl font-bold text-center">Loan Calculator</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="space-y-4">
          <div>
            <label htmlFor="loanAmount" className="block text-sm font-medium text-gray-700">
              Loan Amount ($)
            </label>
            <Input
              id="loanAmount"
              type="number"
              value={loanAmount}
              onChange={(e) => setLoanAmount(e.target.value)}
              placeholder="Enter loan amount"
              className="mt-1"
            />
          </div>
          <div>
            <label htmlFor="interestRate" className="block text-sm font-medium text-gray-700">
              Annual Interest Rate (%)
            </label>
            <Input
              id="interestRate"
              type="number"
              value={interestRate}
              onChange={(e) => setInterestRate(e.target.value)}
              placeholder="Enter interest rate"
              className="mt-1"
            />
          </div>
          <div>
            <label htmlFor="loanTerm" className="block text-sm font-medium text-gray-700">
              Loan Term (years)
            </label>
            <Input
              id="loanTerm"
              type="number"
              value={loanTerm}
              onChange={(e) => setLoanTerm(e.target.value)}
              placeholder="Enter loan term"
              className="mt-1"
            />
          </div>
        </div>
      </CardContent>
      <CardFooter>
        <Button onClick={calculateLoan} className="w-full">
          Calculate
        </Button>
      </CardFooter>
      {monthlyPayment && (
        <CardContent>
          <div className="mt-4 space-y-2">
            <p className="text-sm font-medium">Monthly Payment: ${monthlyPayment}</p>
            <p className="text-sm font-medium">Total Payment: ${totalPayment}</p>
            <p className="text-sm font-medium">Total Interest: ${totalInterest}</p>
          </div>
        </CardContent>
      )}
    </Card>
  );
};

export default LoanCalculator;
