import { Component, OnInit, AfterViewInit, ViewChild, ViewEncapsulation } from '@angular/core';
import { EventSettingsModel, DayService, WeekService, WorkWeekService, MonthService, ScheduleComponent } from '@syncfusion/ej2-angular-schedule';

import { ConsultasService, Consulta } from '../services/consultas.service';
import { UtentesService, Utente } from '../services/utentes.service';
import { MedicosService, Medico } from '../services/medicos.service';
import { HistoricoService, Historico } from '../services/historico.service';
import { AuthService, User } from '../services/auth.service';

@Component({
  selector: 'app-calendario',
  templateUrl: './calendario.component.html',
  styleUrls: ['./calendario.component.css'],
  providers: [DayService, WeekService, WorkWeekService, MonthService],
  encapsulation: ViewEncapsulation.None
})
export class CalendarioComponent implements OnInit, AfterViewInit {
  @ViewChild('scheduleObj') public scheduleObj!: ScheduleComponent;

  consultasUtentes: Consulta[] = [];
  consultas: Consulta[] = [];
  utentes: Utente[] = [];
  utentesInteresse: Utente[] = [];
  medicos: Medico[] = [];
  historico: Historico[] = [];
  user: User | null = null;
  showMenu: boolean = false;
  totalUtentes = 0;
  medicoId = '';

  eventSettings: EventSettingsModel = {
    dataSource: [],
    fields: {
      subject: { name: 'Subject' },
      description: { name: 'Description' },
      startTime: { name: 'StartTime' },
      endTime: { name: 'EndTime' }
    }
  };

  selectedDate: Date = new Date();

  constructor(
    private consultasService: ConsultasService,
    private utentesService: UtentesService,
    private medicosService: MedicosService,
    private historicoService: HistoricoService,
    private authService: AuthService

  ) { }





  ngOnInit(): void {

    const user = this.authService.getUser();
    this.user = user;
    if (!user) {
      console.error("Utilizador não autenticado.");
      return;
    }

    this.authService.getUserAssociation(user._id).subscribe({
      next: (res) => {
        if (res && res.tipo === 'medico') {
          this.medicoId = res.id;
          this.consultasService.getConsultasDoMedico(this.medicoId).subscribe(data => {
            this.consultas = data.resultado;

            this.utentesService.getUtentes().subscribe(data => {
              this.utentes = data;
              /* this.utentesInteresse = this.utentes.filter(
                utente => utente.medicoid === this.medicoId
              ); */

              const eventos: any[] = [];
              let utentesProcessados = 0;
          

              this.utentes.forEach(utente => {
                if (utente.historicoId) {
                  const hist = utente.historicoId;


                  this.historicoService.getHistorico(hist).subscribe(data => {
                    this.historico = data.resultado;

                    this.consultasService.getConsultas(hist).subscribe(data => {
                      this.consultasUtentes = data.resultado;

                      // Filtrar histórico para este médico
                      this.consultasUtentes = this.consultasUtentes.filter(h => h.medico === this.medicoId);
                      if( this.consultasUtentes){
                      this.totalUtentes = this.totalUtentes+1;}

                      this.consultasUtentes.forEach(consulta => {
                        console.log("inserir");
                        const dataConsulta = consulta.data;
                        eventos.push({
                          Id: eventos.length + 1,
                          Subject: `Consulta com ${utente.nome ?? 'Utente'}`,
                          StartTime: consulta.data,
                          EndTime: new Date(new Date(consulta.data).getTime() + 30 * 60000),
                          NomeUtente: utente.nome,
                          Description: `Email: ${utente.email}\nTelefone: ${utente.contacto}`
                        });
                      });

                      utentesProcessados++;
                      if (utentesProcessados === this.totalUtentes) {
                        this.eventSettings = {
                          ...this.eventSettings,
                          dataSource: eventos
                        };
                        if (this.scheduleObj) this.scheduleObj.refreshEvents();
                      }
                    });
                  });
                } else {
                  utentesProcessados++;
                  if (utentesProcessados === this.totalUtentes) {
                    this.eventSettings = {
                      ...this.eventSettings,
                      dataSource: eventos
                    };
                    if (this.scheduleObj) this.scheduleObj.refreshEvents();
                  }
                }
              });
            });
          });

        } else if (res && res.tipo === 'utente') {
          console.warn("O utilizador é um utente, não um médico.");
        } else {
          console.warn("Tipo de associação desconhecido ou inexistente:");
        }
      },
      error: (err) => {
        console.error("Erro ao obter associação do utilizador:");
      }
    });
  }


  ngAfterViewInit(): void {
    setTimeout(() => {
      if (this.scheduleObj) {
        this.scheduleObj.refresh();
      }
    }, 200);
  }
  toggleMenu() {
    console.log('toggleMenu clicado');
    this.showMenu = !this.showMenu;
  }
  logout() {
    this.authService.logout();
  }

  onPopupOpen(args: any): void {
    // Bloquear popup de criação manual
    if (args.type === 'QuickInfo' && args.target?.classList.contains('e-work-cells')) {
      args.cancel = true;
    }

    if (args.type === 'Editor') {
      args.cancel = true;
    }

    if (args.type === 'QuickInfo') {
      // Esconder botões nativos
      setTimeout(() => {
        window.requestAnimationFrame(() => {
          const popupElement = args.element;
          const editBtn = popupElement?.querySelector('.e-event-edit') as HTMLElement;
          const deleteBtn = popupElement?.querySelector('.e-event-delete') as HTMLElement;
          const detailsBtn = popupElement?.querySelector('.e-event-details') as HTMLElement;

          if (editBtn) editBtn.style.display = 'none';
          if (deleteBtn) deleteBtn.style.display = 'none';
          if (detailsBtn) detailsBtn.style.display = 'none';
        });
      }, 100);

      // Inserir conteúdo adicional no popup
      if (args.data) {
        const data = args.data as any;
        const popupElement = args.element;


        const customInfo = document.createElement('div');


        setTimeout(() => {
          const content = popupElement?.querySelector('.e-popup-content');
          if (content) {
            content.appendChild(customInfo);
          }
        }, 50);
      }
    }
  }
  ngOnDestroy(): void {
    if (this.scheduleObj) {
      this.scheduleObj.destroy(); // remove eventos e UI
    }
    // Remove diálogos manualmente se ainda existirem
    const dialogs = document.querySelectorAll(
      '.e-dlg-container.e-schedule-dialog-container, .e-dlg-container.e-quick-dialog'
    );
    dialogs.forEach(dialog => {
      dialog.remove();
    });

  }


  onEventRendered(args: any): void {
    const categoryColor = '#1E3A8A';
    args.element.style.backgroundColor = categoryColor;
    args.element.style.borderColor = categoryColor;
  }
}