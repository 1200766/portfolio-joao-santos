
import { bootstrapApplication } from '@angular/platform-browser';
import { routes } from './app/app.routes'; 
import { provideRouter } from '@angular/router';
import { AppComponent } from './app/app.component';
import { provideHttpClient, withInterceptorsFromDi } from '@angular/common/http';

import { registerLicense } from '@syncfusion/ej2-base';
import { platformBrowserDynamic } from '@angular/platform-browser-dynamic';
import { AppModule } from './app/app.module';

// Configure localmente uma chave propria; nao publique a sua chave.
registerLicense('YOUR_SYNCFUSION_LICENSE_KEY');

platformBrowserDynamic().bootstrapModule(AppModule)
  .catch(err => console.error(err));

bootstrapApplication(AppComponent, {
  providers: [
    provideRouter(routes),
    provideHttpClient(withInterceptorsFromDi()),  ],
});

import { L10n, loadCldr, setCulture } from '@syncfusion/ej2-base';
import * as numberingSystems from 'cldr-data/supplemental/numberingSystems.json';
import * as gregorian from 'cldr-data/main/pt-PT/ca-gregorian.json';
import * as numbers from 'cldr-data/main/pt-PT/numbers.json';
import * as timeZoneNames from 'cldr-data/main/pt-PT/timeZoneNames.json';

loadCldr(numberingSystems, gregorian, numbers, timeZoneNames);

L10n.load({
  'pt-PT': {
    schedule: {
      day: 'Dia',
      week: 'Semana',
      workWeek: 'Semana de trabalho',
      month: 'Mês',
      agenda: 'Agenda',
      today: 'Hoje',
      noEvents: 'Sem eventos',
      emptyContainer: 'Nenhuma consulta agendada para este dia.',
    },
  }
});

setCulture('pt-PT');
